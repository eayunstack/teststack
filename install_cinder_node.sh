#!/bin/bash

prepare_lvm()
{
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb
}

# TODO accep every block device at present.
#/etc/lvm/lvm.conf
#devices {
#...
#filter = [ "a/sda1/", "a/sdb/", "r/.*/"]
#...
#}

install_cinder()
{
yum install -y openstack-cinder  iscsi-initiator-utils
# TODO maybe the latest kernel don't need this any more.
#scsi-target-utils
}

config_cinder()
{
openstack-config --set /etc/cinder/cinder.conf DEFAULT \
auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_host $CONTROLLER_NAME
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken \
admin_password $CINDER_PASS
openstack-config --set /etc/cinder/cinder.conf \
DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT qpid_hostname $CONTROLLER_NAME

openstack-config --set /etc/cinder/cinder.conf \
  database connection mysql://cinder:$CINDER_DBPASS@$CONTROLLER_NAME/cinder
openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT glance_host $CONTROLLER_NAME
sed -i 1'i\include \/etc\/cinder\/volumes\/*' /etc/tgt/targets.conf
}

start_service()
{
service openstack-cinder-volume start
chkconfig openstack-cinder-volume on
# TODO this will cause error. " ensure port 3260 is not in use by another service."
# service tgtd start
# chkconfig tgtd on
}


source openstack_envrc
prepare_lvm
install_cinder
config_cinder
start_service
