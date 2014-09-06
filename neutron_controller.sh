#!/bin/bash

set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

prerequisites()
{
sed -i "s/NEUTRON_DBPASS/$NEUTRON_DBPASS/" neutron.sql
mysql -uroot <neutron.sql
# TODO why empty EMAIL will fail here when keystone/glance/nova won't.
keystone user-create --name neutron --pass $NEUTRON_PASS --email $NEUTRON_EMAIL
keystone user-role-add --user neutron --tenant service --role admin
keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ network / {print $2}') \
  --publicurl http://$CONTROLLER_NAME:9696 \
  --adminurl http://$CONTROLLER_NAME:9696 \
  --internalurl http://$CONTROLLER_NAME:9696
}


install_neutron()
{
yum install -y openstack-neutron openstack-neutron-ml2 python-neutronclient
}

config_neutron()
{
openstack-config --set /etc/neutron/neutron.conf database connection \
  mysql://neutron:$NEUTRON_DBPASS@$CONTROLLER_NAME/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
auth_host $CONTROLLER_NAME
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
admin_password $NEUTRON_PASS

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
qpid_hostname $CONTROLLER_NAME

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
nova_url http://$CONTROLLER_NAME:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
nova_admin_tenant_id $(keystone tenant-list | awk '/ service / { print $2 }')
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
nova_admin_password $NOVA_PASS
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
nova_admin_auth_url http://$CONTROLLER_NAME:35357/v2.0

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
service_plugins router

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre \
tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
enable_security_group True
}


config_compute_to_use_neutron()
{
openstack-config --set /etc/nova/nova.conf DEFAULT \
network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_url http://$CONTROLLER_NAME:9696
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_admin_password $NEUTRON_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_admin_auth_url http://$CONTROLLER_NAME:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT \
linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT \
firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT \
security_group_api neutron
}


finalize()
{
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
service openstack-nova-api restart
service openstack-nova-scheduler restart
service openstack-nova-conductor restart
service neutron-server start
chkconfig neutron-server on
}


source openstack_envrc
set_env
prerequisites
install_neutron
config_neutron
config_compute_to_use_neutron
finalize
