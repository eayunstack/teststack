from fabric.api import env, local, parallel, roles, execute, cd
from fabric.api import run, put, runs_once, settings
import time
# import os

CONTROLLER_IP = "10.10.1.2"
CONTROLLER_NAME = "openstack-controller"


env.key_filename = "~/.ssh/id_rsa"
# env.roledefs = {'controller': ['openstack-controller'],
env.roledefs = {'firstnode': ['ha-controller1'],
                'othernode': ['ha-controller2', 'ha-controller3'],
                'controller': ['ha-controller1', 'ha-controller2', 'ha-controller3'],
                'network': ['openstack-network'],
                'node': ['openstack-compute1', 'openstack-compute2'],
                'cinder': ['openstack-cinder1']}

# hosts = ['openstack-controller', 'openstack-network', 'openstack-compute1', 'openstack-compute2', 'openstack-cinder1']
hosts = ['ha-controller1', 'ha-controller2', 'ha-controller3']


@roles('allinone')
def allinone():
    run('yum upgrade -y')
    run('yum install -y https://rdo.fedorapeople.org/rdo-release.rpm')
    run('yum install -y openstack-packstack')

    run('sed -i "13s#operatingsystemrelease#operatingsystemmajrelease#"'
        ' /usr/lib/python2.7/site-packages/packstack/puppet/templates/prescript.pp')
    run('sed -i "47s#operatingsystemrelease#operatingsystemmajrelease#"'
        ' /usr/lib/python2.7/site-packages/packstack/puppet/templates/amqp.pp')
    run('sed -i "3s#operatingsystemrelease#operatingsystemmajrelease#"'
        ' /usr/lib/python2.7/site-packages/packstack/puppet/templates/mysql_install.pp')

    run('sed -i "40s#\'RedHat\'#\'RedHat\',\'CentOS\'#"'
        ' /usr/share/openstack-puppet/modules/mysql/manifests/params.pp')
    run('sed -i "41s#operatingsystemrelease#operatingsystemmajrelease#"'
        ' /usr/share/openstack-puppet/modules/mysql/manifests/params.pp')

    # may not needed.
    # run('sed -i "112s#\'Fedora\'#\'Fedora\' and $::osoperatingsystemmajrelease < 7#"'
    #    ' /usr/share/openstack-puppet/modules/nova/manifests/compute/libvirt.pp')
    # run('sed -i "107s#operatingsystemrelease#operatingsystemmajrelease#"'
    #    ' /usr/share/openstack-puppet/modules/nova/spec/classes/nova_compute_libvirt_spec.rb')
    # run('sed -i "136s#operatingsystemrelease#operatingsystemmajrelease#"'
    #    ' /usr/share/openstack-puppet/modules/nova/spec/classes/nova_compute_libvirt_spec.rb')
    run('sed -i "44s#\'RedHat\'#\'RedHat\',\'CentOS\'#"'
        ' /usr/share/openstack-puppet/modules/nova/manifests/params.pp')
    run('sed -i "47s#\'RedHat\'#\'RedHat\',\'CentOS\'#"'
        ' /usr/share/openstack-puppet/modules/nova/manifests/params.pp')
    run('sed -i "48s#operatingsystemrelease#operatingsystemmajrelease#"'
        ' /usr/share/openstack-puppet/modules/nova/manifests/params.pp')

    run('sed -i "8s#operatingsystemrelease >= 7#operatingsystemmajrelease >= 7#"'
        ' /usr/share/openstack-puppet/modules/apache/manifests/version.pp')

    run('packstack --allinone')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def config_network():
    run('service NetworkManager stop')
    run('service network start')
    run('chkconfig NetworkManager off')
    run('chkconfig network on')
    run('service firewalld stop')
    run('chkconfig firewalld off')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def install_ntp():
    run('yum install ntp -y')
    run('service ntpd start')
    run('chkconfig ntpd on')


@roles('network', 'node', 'cinder')
def config_ntp():
    run(r'sed -i "N;/server 0.centos.pool.ntp.org iburst/i\server %s iburst" /etc/ntp.conf' % CONTROLLER_NAME)
    run('service ntpd restart')


@roles('controller')
@parallel
def install_mariadb():
    run('yum install mariadb mariadb-server MySQL-python -y')
    run('service mariadb start')
    run('chkconfig mariadb on')
    # TODO ignore this now, if you need security, do it yourself after the script.
    # run('mysql_secure_installation')


@roles('network', 'node', 'cinder')
@parallel
def install_mysqlpython():
    run('yum install MySQL-python -y')


@roles('controller')
def config_mariadb():
    with settings(warn_only=True):
        run(r'sed -i "N;/\[mysqld\]/a\bind-address = %s" /etc/my.cnf' % CONTROLLER_IP)
        s = r'sed -i "N;/\[mysqld\]/a\default-storage-engine = innodb\ninnodb_file_per_table' + \
            r'\ncollation-server = utf8_general_ci\ninit-connect = \'SET NAMES utf8\'' + \
            r'\ncharacter-set-server = utf8" /etc/my.cnf'
        run(s)
        run('service mariadb restart')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def install_rdo():
    run('yum install yum-plugin-priorities -y ')
    local('wget https://rdo.fedorapeople.org/rdo-release.rpm')
    put('rdo-release.rpm')
    run('yum install -y rdo-release.rpm')
    # see here for latest epel-release
    # http://mirrors.hustunique.com/epel/7/x86_64/repoview/epel-release.html
    local('wget http://mirrors.hustunique.com/epel/7/x86_64/e/epel-release-7-1.noarch.rpm')
    put('epel-release-7-1.noarch.rpm')
    run('yum install -y epel-release-7-1.noarch.rpm')
    run('yum clean all')
    run('yum makecache')
    run('yum update -y')


@roles('controller')
@parallel
def install_mq():
    run('yum install qpid-cpp-server -y')
    run('echo "auth=no" >> /etc/qpid/qpidd.conf')
    run('service qpidd start')
    run('chkconfig qpidd on')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def install_misc():
    run('yum install -y psmisc net-tools')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def install_utils():
    run('yum install openstack-utils openstack-selinux -y')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def adjust_base_repo():
    with settings(warn_only=True):
        run('mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo_bak')
    put('Local-Centos-7.repo', '/etc/yum.repos.d/')
    put('RPM-GPG-KEY-CentOS-7', '/etc/pki/rpm-gpg/')
    run('yum clean all')
    run('yum makecache')
    run('yum update -y')


@roles('controller', 'network', 'node', 'cinder')
@parallel
def adjust_rdo_repo():
    put('Local-RDO-icehouse-el7.repo', '/etc/yum.repos.d/')
    put('Local-epel-7.repo', '/etc/yum.repos.d/')
    put('RPM-GPG-KEY-EPEL-7', '/etc/pki/rpm-gpg/')
    put('RPM-GPG-KEY-RDO-Icehouse', '/etc/pki/rpm-gpg/')
    run('yum clean all')
    run('yum makecache')
    run('yum update -y')


def prepare_openstack_env():
    execute(config_network)
    execute(adjust_base_repo)
    execute(install_ntp)
    execute(config_ntp)
    execute(install_mariadb)
    execute(config_mariadb)
    execute(install_mysqlpython)
    # execute(install_rdo)
    execute(adjust_rdo_repo)
    execute(install_utils)
    execute(install_mq)
    execute(install_misc)


@roles('controller')
@runs_once
def install_keystone():
    cd('/tmp')
    put('openstack_envrc')
    put('install_keystone.sh')
    put('keystone.sql')
    run('chmod a+x install_keystone.sh')
    run('./install_keystone.sh')
    run('rm -f install_keystone.sh keystone.sql')
    # TODO test keystone


@roles('controller')
@runs_once
def install_openstack_clients():
    cd('/tmp')
    put('openstack_envrc')
    put('install_openstack_clients.sh')
    run('chmod a+x install_openstack_clients.sh')
    run('./install_openstack_clients.sh')
    run('rm -f install_openstack_clients.sh')


@roles('controller')
@runs_once
def install_glance():
    cd('/tmp')
    put('openstack_envrc')
    put('install_glance.sh')
    put('glance.sql')
    run('chmod a+x install_glance.sh')
    run('./install_glance.sh')
    run('rm -f install_glance.sh glance.sql')


@roles('controller')
@runs_once
def install_nova():
    cd('/tmp')
    put('openstack_envrc')
    put('install_nova.sh')
    put('nova.sql')
    run('chmod a+x install_nova.sh')
    run('./install_nova.sh')
    run('rm -f install_nova.sh nova.sql')


@roles('node')
@parallel
def install_compute():
    cd('/tmp')
    put('openstack_envrc')

    put('install_compute.sh')
    run('chmod a+x install_compute.sh')
    run('./install_compute.sh')
    run('rm -f install_compute.sh')


@roles('controller')
@runs_once
def neutron_controller():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_controller.sh')
    put('neutron.sql')
    run('chmod a+x neutron_controller.sh')
    run('./neutron_controller.sh')
    run('rm -f neutron_controller.sh neutron.sql')


@roles('network')
@runs_once
def neutron_network_network1():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_network_network1.sh')
    run('chmod a+x neutron_network_network1.sh')
    run('./neutron_network_network1.sh')
    run('rm -f neutron_network_network1.sh')


@roles('controller')
@runs_once
def neutron_network_controller():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_network_controller.sh')
    run('chmod a+x neutron_network_controller.sh')
    run('./neutron_network_controller.sh')
    run('rm -f neutron_network_controller.sh')


@roles('network')
@runs_once
def neutron_network_network2():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_network_network2.sh')
    run('chmod a+x neutron_network_network2.sh')
    run('./neutron_network_network2.sh')
    run('rm -f neutron_network_network2.sh')


@roles('node')
@parallel
def neutron_compute():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_compute.sh')
    put('neutron.sql')
    run('chmod a+x neutron_compute.sh')
    run('./neutron_compute.sh')
    run('rm -f neutron_compute.sh neutron.sql')


@roles('controller')
@runs_once
def neutron_create_network():
    cd('/tmp')
    put('openstack_envrc')
    put('neutron_create_network.sh')
    run('chmod a+x neutron_create_network.sh')
    run('./neutron_create_network.sh')
    run('rm -f neutron_create_network.sh')


def install_neutron():
    execute(neutron_controller)
    execute(neutron_network_network1)
    execute(neutron_network_controller)
    execute(neutron_network_network2)
    execute(neutron_compute)
    execute(neutron_create_network)


@roles('controller')
@runs_once
def install_horizon():
    cd('/tmp')
    put('openstack_envrc')
    put('install_horizon.sh')
    run('chmod a+x install_horizon.sh')
    run('./install_horizon.sh')
    run('rm -f install_horizon.sh')


@roles('controller')
@runs_once
def install_cinder_controller():
    cd('/tmp')
    put('openstack_envrc')
    put('install_cinder_controller.sh')
    put('cinder.sql')
    run('chmod a+x install_cinder_controller.sh')
    run('./install_cinder_controller.sh')
    run('rm -f install_cinder_controller.sh cinder.sql')


@roles('cinder')
@runs_once
def install_cinder_node():
    cd('/tmp')
    put('openstack_envrc')
    put('install_cinder_node.sh')
    run('chmod a+x install_cinder_node.sh')
    run('./install_cinder_node.sh')
    run('rm -f install_cinder_node.sh')


@roles('controller')
def install_heat():
    cd('/tmp')
    put('openstack_envrc')
    put('install_heat.sh')
    put('heat.sql')
    run('chmod a+x install_heat.sh')
    run('./install_heat.sh')
    run('rm -f install_heat.sh heat.sql')


@roles('controller')
def install_ceilometer_controller():
    cd('/tmp')
    put('openstack_envrc')
    put('install_ceilometer_controller.sh')
    run('chmod a+x install_ceilometer_controller.sh')
    run('./install_ceilometer_controller.sh')
    run('rm -f install_ceilometer_controller.sh')


@roles('node')
def install_ceilometer_compute():
    cd('/tmp')
    put('openstack_envrc')
    put('install_ceilometer_compute.sh')
    run('chmod a+x install_ceilometer_compute.sh')
    run('./install_ceilometer_compute.sh')
    run('rm -f install_ceilometer_compute.sh')


@roles('controller')
def install_ceilometer_cindercontroller():
    cd('/tmp')
    put('openstack_envrc')
    put('install_ceilometer_cindercontroller.sh')
    run('chmod a+x install_ceilometer_cindercontroller.sh')
    run('./install_ceilometer_cindercontroller.sh')
    run('rm -f install_ceilometer_cindercontroller.sh')


@roles('cinder')
def install_ceilometer_cindernode():
    cd('/tmp')
    put('openstack_envrc')
    put('install_ceilometer_cindernode.sh')
    run('chmod a+x install_ceilometer_cindernode.sh')
    run('./install_ceilometer_cindernode.sh')
    run('rm -f install_ceilometer_cindernode.sh')


def install_ceilometer():
    execute(install_ceilometer_controller)
    execute(install_ceilometer_compute)
    execute(install_ceilometer_cindercontroller)
    execute(install_ceilometer_cindernode)


@roles('controller')
def config_lbaas_controller():
    cd('/tmp')
    put('config_lbaas_controller.sh')
    run('chmod a+x config_lbaas_controller.sh')
    run('./config_lbaas_controller.sh')
    run('rm -f config_lbaas_controller.sh')


@roles('network', 'node')
def config_lbaas_other():
    cd('/tmp')
    put('config_lbaas_other.sh')
    run('chmod a+x config_lbaas_other.sh')
    run('./config_lbaas_other.sh')
    run('rm -f config_lbaas_other.sh')


def config_lbaas():
    execute(config_lbaas_controller)
    execute(config_lbaas_other)


def install_openstack():
    prepare_openstack_env()
    execute(install_keystone)
    execute(install_openstack_clients)
    execute(install_glance)
    execute(install_nova)
    execute(install_compute)
    install_neutron()
    execute(install_horizon)
    execute(install_cinder_controller)
    execute(install_cinder_node)
    install_ceilometer()
    execute(install_heat)


def add_node():
    install_compute()
    neutron_compute()


@roles('controller')
@parallel
def order(command=None):
    run(command)
    time.sleep(2)


@roles('network')
@runs_once
def restart_neutron_network():
    run('service neutron-openvswitch-agent restart')
    run('service neutron-l3-agent restart')
    run('service neutron-dhcp-agent restart')
    run('service neutron-metadata-agent restart')
    run('service neutron-lbaas-agent restart')


@roles('node')
def restart_neutron_node():
    run('service neutron-openvswitch-agent restart')
    run('service neutron-lbaas-agent restart')


@roles('controller')
@runs_once
def restart_neutron_controller():
    run('service neutron-server restart')


def restart_neutron():
    execute(restart_neutron_controller)
    execute(restart_neutron_network)
    execute(restart_neutron_node)


@roles('controller')
def restart_nova_controller():
    run('service openstack-nova-api restart')
    run('service openstack-nova-cert restart')
    run('service openstack-nova-consoleauth restart')
    run('service openstack-nova-scheduler restart')
    run('service openstack-nova-conductor restart')
    run('service openstack-nova-novncproxy restart')


@roles('node')
def restart_nova_compute():
    run('service openstack-nova-compute restart')


def restart_nova():
    execute(restart_nova_controller)
    execute(restart_nova_compute)


@roles('controller')
def restart_ceilometer():
    run('service openstack-ceilometer-api restart')
    run('service openstack-ceilometer-notification restart')
    run('service openstack-ceilometer-central restart')
    run('service openstack-ceilometer-collector restart')
    run('service openstack-ceilometer-alarm-evaluator restart')
    run('service openstack-ceilometer-alarm-notifier restart')


def create_snapshot(name=None):
    for i in hosts:
        if name:
            local('virsh snapshot-create-as %s %s' % (i, name))
        else:
            local('virsh snapshot-create %s' % i)


def delete_snapshot(name):
    for i in hosts:
        local('virsh snapshot-delete %s %s' % (i, name))


def revert_to_snapshot(name):
    for i in hosts:
        local("virsh snapshot-revert %s %s" % (i, name))


def start_vms():
    for i in hosts:
        local("virsh start %s" % i)


# =======================================
#   Under methods are made for ha
# =======================================

@roles('controller')
@parallel
def install_keepalived_haproxy():
    cd('/tmp')
    put('openstack_envrc')
    put('install_keepalived_haproxy.sh')
    run('chmod a+x install_keepalived_haproxy.sh')
    run('./install_keepalived_haproxy.sh')
    run('rm -f install_keepalived_haproxy.sh')


@roles('controller')
# This can't be parallel
def install_galera():
    cd('/tmp')
    put('openstack_envrc')
    put('install_galera.sh')
    run('chmod a+x install_galera.sh')
    run('./install_galera.sh')
    run('rm -f install_galera.sh')


@roles('controller')
def install_rabbitmq1():
    run('yum install -y rabbitmq-server')
    run('service rabbitmq-server start')
    run('chkconfig rabbitmq-server on')
    run('service rabbitmq-server stop')


@roles('firstnode')
def install_rabbitmq2():
    for i in ['10.10.1.51', '10.10.1.52']:
        run('scp /var/lib/rabbitmq/.erlang.cookie %s:/var/lib/rabbitmq/.erlang.cookie' % i)


@roles('controller')
def install_rabbitmq3():
    run('service rabbitmq-server start')
    run('rabbitmqctl cluster_status')


@roles('othernode')
@parallel
def install_rabbitmq4():
    run('rabbitmqctl stop_app')
    run('rabbitmqctl join_cluster rabbit@ha-controller1')
    run('rabbitmqctl start_app')
    run('rabbitmqctl cluster_status')


def install_rabbitmq():
    execute(install_rabbitmq1)
    execute(install_rabbitmq2)
    execute(install_rabbitmq3)
    execute(install_rabbitmq4)


@roles('controller')
@parallel
def install_keystone_ha():
    cd('/tmp')
    put('openstack_envrc')
    put('install_keystone_ha.sh')
    put('keystone.sql')
    run('chmod a+x install_keystone_ha.sh')
    run('./install_keystone_ha.sh')
    run('rm -f install_keystone_ha.sh keystone_ha.sql')
