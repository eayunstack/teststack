#!/bin/bash

install_keystone()
{
  yum install -y openstack-keystone python-keystoneclient
}

config_keystone()
{
  ADMIN_TOKEN=$(openssl rand -hex 10)
  config_keystone_normal
  define_utr
  define_services
}

config_keystone_normal()
{
  openstack-config --set /etc/keystone/keystone.conf \
    database connection mysql://keystone:$KEYSTONE_DBPASS@$CONTROLLER_NAME/keystone
  sed -i "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/" keystone.sql
  mysql -uroot <keystone.sql
  su -s /bin/sh -c "keystone-manage db_sync" keystone
  openstack-config --set /etc/keystone/keystone.conf DEFAULT \
    admin_token $ADMIN_TOKEN
  keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
  chown -R keystone:keystone /etc/keystone/ssl
  chmod -R o-rwx /etc/keystone/ssl
  chown -R keystone:keystone /var/log/keystone
  service openstack-keystone start
  chkconfig openstack-keystone on
  (crontab -l -u keystone 2>&1 | grep -q token_flush) || \
    echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/keystone
}


define_utr()
{
  # TODO hostname
  export OS_SERVICE_TOKEN=$ADMIN_TOKEN
  export OS_SERVICE_ENDPOINT=http://$CONTROLLER_NAME:35357/v2.0
  # Administrator
  keystone user-create --name=admin --pass=$ADMIN_PASS --email=$ADMIN_EMAIL
  keystone role-create --name=admin
  keystone tenant-create --name=admin --description="Admin Tenant"
  keystone user-role-add --user=admin --tenant=admin --role=admin
  keystone user-role-add --user=admin --role=_member_ --tenant=admin
  # Normal user
  keystone user-create --name=demo --pass=$DEMO_PASS --email=$DEMO_EMAIL
  keystone tenant-create --name=demo --description="Demo Tenant"
  keystone user-role-add --user=demo --role=_member_ --tenant=demo
  # Service Tenant
  keystone tenant-create --name=service --description="Service Tenant"
}

define_services()
{
  # TODO hostname
  keystone service-create --name=keystone --type=identity \
    --description="OpenStack Identity"
  keystone endpoint-create \
    --service-id=$(keystone service-list | awk '/ identity / {print $2}') \
    --publicurl=http://$CONTROLLER_NAME:5000/v2.0 \
    --internalurl=http://$CONTROLLER_NAME:5000/v2.0 \
    --adminurl=http://$CONTROLLER_NAME:35357/v2.0
}


source openstack_envrc
install_keystone
config_keystone

