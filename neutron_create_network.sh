#!/bin/bash
set_env_admin()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}


set_env_demo()
{
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_TENANT_NAME=demo
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

create_network()
{
set_env_admin
  # external network
neutron net-create ext-net --shared --router:external=True
  # subnet in ext
neutron subnet-create ext-net --name ext-subnet \
  --allocation-pool start=$FLOATING_IP_START,end=$FLOATING_IP_END \
  --disable-dhcp --gateway $EXTERNAL_NETWORK_GATEWAY $EXTERNAL_NETWORK_CIDR

set_env_demo
  # tenant network
neutron net-create demo-net
  # subnet in tenant
neutron subnet-create demo-net --name demo-subnet \
  --gateway $TENANT_NETWORK_GATEWAY $TENANT_NETWORK_CIDR
  # create router
neutron router-create demo-router
  # add nets to router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net
}

source openstack_envrc
create_network
