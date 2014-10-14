#!/bin/bash

set_env()
{
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://$CONTROLLER_NAME:35357/v2.0
}

install_ceilometer()
{
  # mongodb is on the same server with controller.
  yum install -y openstack-ceilometer-api openstack-ceilometer-collector \
  openstack-ceilometer-notification openstack-ceilometer-central openstack-ceilometer-alarm \
  python-ceilometerclient mongodb-server mongodb
}

config_mongo()
{
  sed -i "s/bind_ip = 127.0.0.1/bind_ip = $CONTROLLER_IP/g" /etc/mongodb.conf
  service mongod start
  chkconfig mongod on
  # create mongodb user
  mongo --host controller --eval '
db = db.getSiblingDB("ceilometer");
db.addUser({user: "ceilometer",
            pwd: "'$CEILOMETER_DBPASS'",
            roles: [ "readWrite", "dbAdmin" ]})'

}

config_ceilometer()
{
  config_mongo

  openstack-config --set /etc/ceilometer/ceilometer.conf \
  database connection mongodb://ceilometer:$CEILOMETER_DBPASS@$CONTROLLER_NAME:27017/ceilometer

  openstack-config --set /etc/ceilometer/ceilometer.conf publisher metering_secret $CEILOMETER_TOKEN

  openstack-config --set /etc/ceilometer/ceilometer.conf \
  DEFAULT rpc_backend ceilometer.openstack.common.rpc.impl_qpid
  keystone user-create --name=ceilometer --pass=$CEILOMETER_PASS --email=$CEILOMETER_EMAIL
  keystone user-role-add --user=ceilometer --tenant=service --role=admin
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  DEFAULT auth_strategy keystone

  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken auth_host $CONTROLLER_NAME
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_user ceilometer
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_tenant_name service
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken auth_protocol http
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken auth_uri http://$CONTROLLER_NAME:5000
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  keystone_authtoken admin_password $CEILOMETER_PASS
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_auth_url http://$CONTROLLER_NAME:5000/v2.0
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_username ceilometer
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_tenant_name service
  openstack-config --set /etc/ceilometer/ceilometer.conf \
  service_credentials os_password $CEILOMETER_PASS

  keystone service-create --name=ceilometer --type=metering \
  --description="Telemetry"
  keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ metering / {print $2}') \
  --publicurl=http://$CONTROLLER_NAME:8777 \
  --internalurl=http://$CONTROLLER_NAME:8777 \
  --adminurl=http://$CONTROLLER_NAME:8777

}

start_ceilometer()
{
  service openstack-ceilometer-api start
  service openstack-ceilometer-notification start
  service openstack-ceilometer-central start
  service openstack-ceilometer-collector start
  service openstack-ceilometer-alarm-evaluator start
  service openstack-ceilometer-alarm-notifier start
  chkconfig openstack-ceilometer-api on
  chkconfig openstack-ceilometer-notification on
  chkconfig openstack-ceilometer-central on
  chkconfig openstack-ceilometer-collector on
  chkconfig openstack-ceilometer-alarm-evaluator on
  chkconfig openstack-ceilometer-alarm-notifier on
}

config_glance()
{
  # configure glance
  openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
  service openstack-glance-api restart
  service openstack-glance-registry restart
}
source openstack_envrc
set_env
install_ceilometer
config_ceilometer
start_ceilometer
