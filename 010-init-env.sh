#!/bin/bash
set -ex

OS_DISTRO=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}')
if [ $OS_DISTRO == Red ]; then
    sudo yum update -y
    sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm
    sudo yum install -y yum-utils python-pip python-devel
    sudo yum groupinstall -y 'development tools'
    sudo yum -y install ceph-common git jq nmap bridge-utils net-tools

    sudo setenforce 0
elif [ $OS_DISTRO == CentOS ]; then
    sudo yum update -y
    #sudo yum install -y epel-release
    sudo yum install -y yum-utils python-pip python-devel
    sudo yum groupinstall -y 'development tools'
    sudo yum -y install ceph-common git jq nmap bridge-utils net-tools

    sudo setenforce 0
    sudo systemctl stop firewalld
    # TODO Don't leave firewall disabled permanently, use only for TACO-AIO
    sudo systemctl disable firewalld
elif [ $OS_DISTRO == Ubuntu ]; then
    sudo apt-get update
    sudo apt-get -y upgrade
    sudo apt install -y python python-pip
    sudo apt install -y ceph-common git jq nmap bridge-utils ipcalc
else
    echo "This Linux Distribution is NOT supported"
fi
sudo pip install --upgrade pip==9.0.3
sudo pip install 'pyOpenSSL==16.2.0'
sudo pip install 'python-openstackclient'

sudo sed -i '/swap/s/^/#/g' /etc/fstab
sudo modprobe rbd
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
