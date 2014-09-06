#!/bin/bash

set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

install_glance()
{
yum install -y openstack-glance python-glanceclient
}

config_glance()
{
openstack-config --set /etc/glance/glance-api.conf database \
  connection mysql://glance:$GLANCE_DBPASS@$CONTROLLER_NAME/glance
openstack-config --set /etc/glance/glance-registry.conf database \
  connection mysql://glance:$GLANCE_DBPASS@$CONTROLLER_NAME/glance

openstack-config --set /etc/glance/glance-api.conf DEFAULT \
  rpc_backend qpid
openstack-config --set /etc/glance/glance-api.conf DEFAULT \
  qpid_hostname $CONTROLLER_NAME
sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/" glance.sql
mysql -uroot <glance.sql
su -s /bin/sh -c "glance-manage db_sync" glance

keystone user-create --name=glance --pass=$GLANCE_PASS \
 --email=$GLANCE_EMAIL
keystone user-role-add --user=glance --tenant=service --role=admin

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
auth_host $CONTROLLER_NAME
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
admin_password $GLANCE_PASS
openstack-config --set /etc/glance/glance-api.conf paste_deploy \
flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
auth_host $CONTROLLER_NAME
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
admin_password $GLANCE_PASS
openstack-config --set /etc/glance/glance-registry.conf paste_deploy \
flavor keystone

keystone service-create --name=glance --type=image \
--description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:9292 \
--internalurl=http://$CONTROLLER_NAME:9292 \
--adminurl=http://$CONTROLLER_NAME:9292

service openstack-glance-api start
service openstack-glance-registry start
chkconfig openstack-glance-api on
chkconfig openstack-glance-registry on
}

# TODO test glance

source openstack_envrc
set_env
install_glance
config_glance

