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
cat >>/etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF
sysctl -p
}

install_neutron()
{
yum install -y openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-openvswitch
}


config_neutron()
{
  # config neutron to use keystone
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

# config neutron to use qpidd
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
qpid_hostname $CONTROLLER_NAME

# config neutron to use ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
service_plugins router

# config l3 agent
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT \
interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT \
use_namespaces True

# config dhcp agent
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
use_namespaces True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
  dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
echo 'dhcp-option-force=26,1454' > /etc/neutron/dnsmasq-neutron.conf
killall dnsmasq

# config metadata agent
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
auth_url http://$CONTROLLER_NAME:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
admin_password $NEUTRON_PASS
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
nova_metadata_ip $CONTROLLER_NAME
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
metadata_proxy_shared_secret $METADATA_SECRET
}

source openstack_envrc
prerequisites
install_neutron
config_neutron
