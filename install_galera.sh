#!/bin/bash

NODE_NAME=$(hostname -s)
NODE_IP=$(ip addr list eth1|grep 'inet '|head -1|awk '{print $2}'| cut -d/ -f 1)

CONTROLLER_VIRT_IP=10.10.1.60

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0
yum install -y mariadb-galera-server mariadb rsync psmisc

if [[ $NODE_IP == "10.10.1.50" ]];then

  service mariadb start
  sleep 5

  #Add galera user for mysql cluster
  mysql -e "SET wsrep_on=OFF; GRANT ALL ON *.* TO galera@'%' IDENTIFIED BY 'abc123';"
  mysql -e "SET wsrep_on=OFF; DELETE FROM mysql.user WHERE user=''"

  #Add haproxy user for haproxy.
  mysql -e "insert into mysql.user (Host,User) values ('10.10.1.50','haproxy');"
  mysql -e "insert into mysql.user (Host,User) values ('10.10.1.51','haproxy');"
  mysql -e "insert into mysql.user (Host,User) values ('10.10.1.52','haproxy');"
  mysql -e "flush privileges;"

  service mariadb stop

  #Configure galera
  sed -i 's/wsrep_sst_auth=root:/wsrep_sst_auth=galera:abc123/g' /etc/my.cnf.d/galera.cnf
  sed -i "s/#wsrep_node_address=/wsrep_node_address=\"$NODE_IP\"/g" /etc/my.cnf.d/galera.cnf
  sed -i "s/#wsrep_node_name=/wsrep_node_name=\"$NODE_NAME\"/g" /etc/my.cnf.d/galera.cnf
  sed -i "s#wsrep_provider=none#wsrep_provider=/usr/lib64/galera/libgalera_smm.so#g"  /etc/my.cnf.d/galera.cnf
  sed -i "s/bind-address=0.0.0.0/bind-address=$NODE_IP/g" /etc/my.cnf.d/galera.cnf

  echo "wsrep_cluster_address=gcomm://" >> /etc/my.cnf.d/galera.cnf
  service mariadb start
  #Change back configuration on first node
  sed -i "s#wsrep_cluster_address=gcomm://#wsrep_cluster_address=gcomm://10.10.1.50,10.10.1.51,10.10.1.52#g" /etc/my.cnf.d/galera.cnf
else
  #Configure galera
  sed -i 's/wsrep_sst_auth=root:/wsrep_sst_auth=galera:abc123/g' /etc/my.cnf.d/galera.cnf
  sed -i "s/#wsrep_node_address=/wsrep_node_address=\"$NODE_IP\"/g" /etc/my.cnf.d/galera.cnf
  sed -i "s/#wsrep_node_name=/wsrep_node_name=\"$NODE_NAME\"/g" /etc/my.cnf.d/galera.cnf
  sed -i "s#wsrep_provider=none#wsrep_provider=/usr/lib64/galera/libgalera_smm.so#g"  /etc/my.cnf.d/galera.cnf
  sed -i "s/bind-address=0.0.0.0/bind-address=$NODE_IP/g" /etc/my.cnf.d/galera.cnf

  echo "wsrep_cluster_address=gcomm://10.10.1.50,10.10.1.51,10.10.1.52" >> /etc/my.cnf.d/galera.cnf

  service mariadb start
fi

#Configure haproxy
cat >> /etc/haproxy/haproxy.cfg <<EOF

listen galera 10.10.1.60:3306
        balance source
        mode tcp
        option tcpka
        option mysql-check user haproxy
        server ha-controller1 10.10.1.50:3306 check weight 1
        server ha-controller2 10.10.1.51:3306 check weight 1
        server ha-controller3 10.10.1.52:3306 check weight 1
EOF

service haproxy restart
