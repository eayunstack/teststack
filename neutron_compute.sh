#!/bin/bash

prerequisites()
{
cat >>/etc/sysctl.conf <<EOF
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF
sysctl -p
}


install_neutron()
{
yum install -y openstack-neutron-ml2 openstack-neutron-openvswitch
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

}


config_ml2()
{
  # TODO ipaddress
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

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs \
local_ip $COMPUTE_TUN_IP
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs \
tunnel_type gre
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs \
enable_tunneling True
}

config_ovs()
{
service openvswitch start
chkconfig openvswitch on
ovs-vsctl add-br br-int
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
service openstack-nova-compute restart
service neutron-openvswitch-agent start
chkconfig neutron-openvswitch-agent on
}

source openstack_envrc

COMPUTE_IP=$(ip addr list eth0|grep 'inet '|awk '{print $2}'| cut -d/ -f 1)
COMPUTE_NAME=$(hostname -s)
COMPUTE_TUN_IP=$(ip addr list eth1|grep 'inet '|awk '{print $2}'| cut -d/ -f 1)

prerequisites
install_neutron
config_neutron
config_ml2
config_ovs
config_compute_to_use_neutron
finalize
