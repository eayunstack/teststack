#!/bin/bash


set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

install_cinder()
{
yum install -y openstack-cinder
}

config_cinder()
{
openstack-config --set /etc/cinder/cinder.conf \
database connection mysql://cinder:$CINDER_DBPASS@$CONTROLLER_NAME/cinder
sed -i "s/CINDER_DBPASS/$CINDER_DBPASS/" cinder.sql
mysql -uroot <cinder.sql
su -s /bin/sh -c "cinder-manage db sync" cinder
keystone user-create --name=cinder --pass=$CINDER_PASS --email=$CINDER_EMAIL
keystone user-role-add --user=cinder --tenant=service --role=admin

openstack-config --set /etc/cinder/cinder.conf DEFAULT \
auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_host $CONTROLLER_NAME
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_password $CINDER_PASS

openstack-config --set /etc/cinder/cinder.conf \
DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
openstack-config --set /etc/cinder/cinder.conf \
DEFAULT qpid_hostname $CONTROLLER_NAME 

keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:8776/v1/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_NAME:8776/v1/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_NAME:8776/v1/%\(tenant_id\)s

keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:8776/v2/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_NAME:8776/v2/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_NAME:8776/v2/%\(tenant_id\)s

service openstack-cinder-api start
service openstack-cinder-scheduler start
chkconfig openstack-cinder-api on
chkconfig openstack-cinder-scheduler on
}

source openstack_envrc
set_env
install_cinder
config_cinder
