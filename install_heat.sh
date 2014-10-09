#!/bin/bash

set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}


install_heat()
{
yum install -y openstack-heat-api openstack-heat-engine \
  openstack-heat-api-cfn
}

config_heat()
{
openstack-config --set /etc/heat/heat.conf \
    database connection mysql://heat:$HEAT_DBPASS@$CONTROLLER_NAME/heat

sed -i "s/HEAT_DBPASS/$HEAT_DBPASS/" heat.sql
mysql -uroot <heat.sql

su -s /bin/sh -c "heat-manage db_sync" heat

openstack-config --set /etc/heat/heat.conf DEFAULT qpid_hostname $CONTROLLER_NAME

keystone user-create --name=heat --pass=$HEAT_PASS --email=$HEAT_EMAIL
keystone user-role-add --user=heat --tenant=service --role=admin

openstack-config --set /etc/heat/heat.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000/v2.0
openstack-config --set /etc/heat/heat.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/heat/heat.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/heat/heat.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/heat/heat.conf keystone_authtoken \
admin_user heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken \
admin_password $HEAT_PASS
openstack-config --set /etc/heat/heat.conf ec2authtoken \
auth_uri http://$CONTROLLER_NAME:5000/v2.0

keystone service-create --name=heat --type=orchestration \
--description="Orchestration"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ orchestration / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:8004/v1/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_NAME:8004/v1/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_NAME:8004/v1/%\(tenant_id\)s
keystone service-create --name=heat-cfn --type=cloudformation \
--description="Orchestration CloudFormation"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ cloudformation / {print $2}') \
--publicurl=http://$CONTROLLER_NAME:8000/v1 \
--internalurl=http://$CONTROLLER_NAME:8000/v1 \
--adminurl=http://$CONTROLLER_NAME:8000/v1

keystone role-create --name heat_stack_user

openstack-config --set /etc/heat/heat.conf \
DEFAULT heat_metadata_server_url http://$CONTROLLER_IP:8000
openstack-config --set /etc/heat/heat.conf \
DEFAULT heat_waitcondition_server_url http://$CONTROLLER_IP:8000/v1/waitcondition

service openstack-heat-api start
service openstack-heat-api-cfn start
service openstack-heat-engine start
chkconfig openstack-heat-api on
chkconfig openstack-heat-api-cfn on
chkconfig openstack-heat-engine on
}

source openstack_envrc
set_env
install_heat
config_heat
