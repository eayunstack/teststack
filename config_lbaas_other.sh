#!/bin/bash

yum install -y haproxy

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  service_plugins router,lbaas

openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT \
  device_driver neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver

openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT \
  interface_driver neutron.agent.linux.interface.OVSInterfaceDriver 

#[BUG] https://bugs.launchpad.net/devstack/+bug/1283064
openstack-config --set /etc/neutron/lbaas_agent.ini haproxy \
  user_group nobody

service neutron-lbaas-agent start
chkconfig neutron-lbaas-agent on
