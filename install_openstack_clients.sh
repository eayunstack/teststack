#!/bin/bash

source openstack_envrc

clients="ceilometer cinder glance heat keystone neutron nova swift trove"

for client in $clients
do 
  yum install -y python-${client}client
done

cat > admin-openrc.sh << EOF
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
EOF

cat > demo-openrc.sh << EOF
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_TENANT_NAME=demo
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
EOF
