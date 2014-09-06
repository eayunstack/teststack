teststack
=========

Automated scripts to install openstack in test or development environment.


####Environment Requirements:
You need to config your hosts environment before invoking this script.
This script uses a default configuration, which you can change as your wish in file openstack_envrc and fabfile.py :

1. networks  
    management-network: 10.10.1.0/24
    tunnel-network: 10.10.2.0/24
    external-network: 192.168.122.0/24

2. openstack-controller
    * eth0--management network  
        ip: 10.10.1.2
    * eth1--(optional)probably external network, so you can easily visit horizon.

3. openstack-network
    * eth0--management network
        ip: 10.10.1.3
        gw: 10.10.1.1
    * eth1--tunnel network
        ip: 10.10.2.3
    * eth2--external network
        no ip

4. openstack-node1
    * eth0--management network
        ip: 10.10.1.4
        gw: 10.10.1.1
    * eth1--tunnel network
        ip: 10.10.2.4

5. openstack-cinder1
    * eth0--management network
        ip: 10.10.1.5
        gw: 10.10.1.1

For detailed environment requirements, see [openstack network requirements](http://docs.openstack.org/icehouse/install-guide/install/yum/content/basics-networking-neutron.html)

####Requirements:
This script uses fabric, when invoked, it will ssh to hosts above and do the job.
It requires you to config password-less login between your hosts, which includes the host(LocalHost) you are working on.

To install fabric on LocalHost:

* Debian/Ubuntu/LinuxMint:

        sudo apt-get install fabric

* RedHat/CentOS/Fedora:

        yum install python-setuptools
        easy_install pip
        pip install fabric

To fire up:
    
    cd teststack/
    fab install_openstack


**NOTE: For now the repos used here are eayun internal repos, you need to change .repo files youself if you want to use
this outside of eayun network.**
