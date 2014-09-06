#!/bin/bash


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
local_ip $NETWORK_TUN_IP
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
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $NETWORK_EX_INTERFACE
ethtool -K $NETWORK_EX_INTERFACE gro off
}

finalize()
{
ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
# Old CentOS6 problem
#cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
#sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent
service neutron-openvswitch-agent start
service neutron-l3-agent start
service neutron-dhcp-agent start
service neutron-metadata-agent start
chkconfig neutron-openvswitch-agent on
chkconfig neutron-l3-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-metadata-agent on
}

source openstack_envrc
config_ml2
config_ovs
finalize
