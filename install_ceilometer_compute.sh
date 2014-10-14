#!/bin/bash

install_ceilometer()
{
yum install -y openstack-ceilometer-compute python-ceilometerclient python-pecan
}


config_ceilometer()
{
  openstack-config --set /etc/nova/nova.conf DEFAULT \
  instance_usage_audit True
  openstack-config --set /etc/nova/nova.conf DEFAULT \
  instance_usage_audit_period hour
  openstack-config --set /etc/nova/nova.conf DEFAULT \
  notify_on_state_change vm_and_task_state


sed -i "N;/\[DEFAULT\]/a\notification_driver = nova.openstack.common.notifier.rpc_notifier\nnotification_driver = ceilometer.compute.nova_notifier" /etc/nova/nova.conf

service openstack-nova-compute restart
openstack-config --set /etc/ceilometer/ceilometer.conf publisher \
  metering_secret $CEILOMETER_TOKEN

  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend ceilometer.openstack.common.rpc.impl_qpid
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT qpid_hostname $CONTROLLER_NAME

  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken auth_host $CONTROLLER_NAME
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_user ceilometer
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_tenant_name service
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken auth_protocol http
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_password $CEILOMETER_PASS
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_username ceilometer
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_tenant_name service
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_password $CEILOMETER_PASS
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_auth_url http://$CONTROLLER_NAME:5000/v2.0

  service openstack-ceilometer-compute start
  chkconfig openstack-ceilometer-compute on
}

source openstack_envrc
install_ceilometer
config_ceilometer
