#!/bin/bash

set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

install_nova()
{
yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
python-novaclient
}

config_nova()
{
openstack-config --set /etc/nova/nova.conf \
  database connection mysql://nova:$NOVA_DBPASS@$CONTROLLER_NAME/nova
openstack-config --set /etc/nova/nova.conf \
  DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $CONTROLLER_NAME

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $CONTROLLER_IP

# TODO find the time to skip these two configurations below.
openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal False
openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 0

sed -i "s/NOVA_DBPASS/$NOVA_DBPASS/" nova.sql
mysql -uroot <nova.sql

su -s /bin/sh -c "nova-manage db sync" nova

keystone user-create --name=nova --pass=$NOVA_PASS --email=$NOVA_EMAIL
keystone user-role-add --user=nova --tenant=service --role=admin

openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $CONTROLLER_NAME
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $NOVA_PASS

keystone service-create --name=nova --type=compute \
--description="OpenStack Compute"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:8774/v2/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_NAME:8774/v2/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_NAME:8774/v2/%\(tenant_id\)s

service openstack-nova-api start
service openstack-nova-cert start
service openstack-nova-consoleauth start
service openstack-nova-scheduler start
service openstack-nova-conductor start
service openstack-nova-novncproxy start
chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-consoleauth on
chkconfig openstack-nova-scheduler on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-novncproxy on
}


source openstack_envrc
set_env
install_nova
config_nova
