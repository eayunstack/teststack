#!/bin/bash

source openstack_envrc
openstack-config --set /etc/nova/nova.conf DEFAULT \
service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT \
neutron_metadata_proxy_shared_secret $METADATA_SECRET
service openstack-nova-api restart
