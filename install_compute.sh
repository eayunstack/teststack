#!/bin/bash

install_compute()
{
yum install -y openstack-nova-compute
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$NOVA_DBPASS@$CONTROLLER_NAME/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_NAME:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host $CONTROLLER_NAME
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $NOVA_PASS
openstack-config --set /etc/nova/nova.conf \
DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname $CONTROLLER_NAME
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $COMPUTE_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $COMPUTE_IP

# TODO find the time to skip these two configurations below.
openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal False
openstack-config --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 0

openstack-config --set /etc/nova/nova.conf \
DEFAULT novncproxy_base_url http://$CONTROLLER_NAME:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT glance_host $CONTROLLER_NAME
service libvirtd start
#service messagebus start
service openstack-nova-compute start
chkconfig libvirtd on
#chkconfig messagebus on
chkconfig openstack-nova-compute on
}


source openstack_envrc
install_compute
