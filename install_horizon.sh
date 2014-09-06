#!/bin/bash


# TODO choose different session storage backend

install_horizon()
{
yum install -y memcached python-memcached mod_wsgi openstack-dashboard
}

config_horizon()
{
  cat >>/etc/openstack-dashboard/local_settings <<EOF
CACHES = {
'default': {
'BACKEND' : 'django.core.cache.backends.memcached.MemcachedCache',
'LOCATION' : '127.0.0.1:11211'
}
}
EOF

# TODO change allowed host
sed -i "s#ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]#ALLOWED_HOSTS = \['*', 'localhost'\]#g" \
  /etc/openstack-dashboard/local_settings

# TODO set openstack_host if it's not localhost.
#OPENSTACK_HOST = "openstack-controller"
#sed -i 's#OPENSTACK_HOST = "127.0.0.1"#OPENSTACK_HOST = "openstack-controller"'
#  /etc/openstack-dashboard/local_settings

# selinux policy
setsebool -P httpd_can_network_connect on


service httpd start
service memcached start
chkconfig httpd on
chkconfig memcached on
}

source openstack_envrc
install_horizon
config_horizon
