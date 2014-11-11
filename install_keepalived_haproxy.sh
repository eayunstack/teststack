#!/bin/bash

install()
{
#psmic needed for killall
yum install -y keepalived haproxy psmisc
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
}

config_keepalived()
{
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
  router_id $NODE_NAME
}
vrrp_script haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}
vrrp_instance 50 {
  virtual_router_id 50
  advert_int 1
  priority 101
  state MASTER
  interface eth1
  virtual_ipaddress {
    $CONTROLLER_VIRT_IP dev eth1
  }
  track_script {
    haproxy
  }
}
EOF

echo 'net.ipv4.ip_nonlocal_bind=1' >> /etc/sysctl.conf
sysctl -p
}

config_haproxy()
{

cat > /etc/haproxy/haproxy.cfg << EOF
global
  chroot  /var/lib/haproxy
  daemon
  group  haproxy
  maxconn  4000
  pidfile  /var/run/haproxy.pid
  user  haproxy

defaults
  log  global
  maxconn  8000
  option  redispatch
  retries  3
  timeout  http-request 10s
  timeout  queue 1m
  timeout  connect 10s
  timeout  client 1m
  timeout  server 1m
  timeout  check 10s
EOF
}

start_service()
{
chkconfig haproxy on
chkconfig keepalived on
service keepalived start
service haproxy start
}

NODE_NAME=$(hostname -s)
NODE_IP=$(ip addr list eth1|grep 'inet '|awk '{print $2}'| cut -d/ -f 1)

CONTROLLER_VIRT_IP=10.10.1.60

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0

install
config_keepalived
config_haproxy
start_service
