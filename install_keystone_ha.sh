#!/bin/bash

install_keystone()
{
  yum install -y MySQL-python openstack-keystone openstack-utils openstack-selinux
}

config_keystone()
{
  config_keystone_normal
  config_haproxy
  sleep 2
  if [ $NODE_IP == '10.10.1.50' ];then
    define_utr
    define_services
  fi
}

config_keystone_normal()
{
  #TODO this is for ha, need to adjust.
  if [ $NODE_IP == '10.10.1.50' ];then
    sed -i "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/" keystone.sql
    mysql -uroot <keystone.sql
    su -s /bin/sh -c "keystone-manage db_sync" keystone
    for i in 10.10.1.51 10.10.1.52
    do
      scp -r /etc/keystone/ssl $i:/etc/keystone
    done
  else
    sleep 5
  fi

  openstack-config --set /etc/keystone/keystone.conf \
    database connection mysql://keystone:$KEYSTONE_DBPASS@$CONTROLLER_NAME/keystone
  openstack-config --set /etc/keystone/keystone.conf DEFAULT \
    admin_token $ADMIN_TOKEN
  openstack-config --set /etc/keystone/keystone.conf DEFAULT \
    admin_bind_host $NODE_IP
openstack-config --set /etc/keystone/keystone.conf DEFAULT \
    public_bind_host $NODE_IP
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

config_haproxy()
{
cat >> /etc/haproxy/haproxy.cfg << EOF

listen keystone_admin 10.10.1.60:35357
        balance source
        option tcpka
        option httpchk
        maxconn 10000
        server ha-controller1 10.10.1.50:35357 check inter 2000 rise 2 fall 5
        server ha-controller2 10.10.1.51:35357 check inter 2000 rise 2 fall 5
        server ha-controller3 10.10.1.52:35357 check inter 2000 rise 2 fall 5

listen keystone_api 10.10.1.60:5000
        balance source
        option tcpka
        option httpchk
        maxconn 10000
        server ha-controller1 10.10.1.50:5000 check inter 2000 rise 2 fall 5
        server ha-controller2 10.10.1.51:5000 check inter 2000 rise 2 fall 5
        server ha-controller3 10.10.1.52:5000 check inter 2000 rise 2 fall 5

EOF
service haproxy restart
}

NODE_NAME=$(hostname -s)
NODE_IP=$(ip addr list eth1|grep 'inet '|head -1|awk '{print $2}'| cut -d/ -f 1)
source openstack_envrc
install_keystone
config_keystone
