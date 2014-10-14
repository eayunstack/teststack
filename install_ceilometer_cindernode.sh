#!/bin/bash

  openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
  openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier

  service openstack-cinder-volume restart
