#!/bin/bash

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
service_plugins router,lbaas

service neutron-server restart


sed -i "s/'enable_lb': False,/'enable_lb': True,/g"  /etc/openstack-dashboard/local_settings

service httpd restart
