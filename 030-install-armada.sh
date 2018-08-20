#!/bin/bash
set -ex

ARMADA_DIR=~/apps/armada
if [ -d $ARMADA_DIR ]; then
  rm -rf $ARMADA_DIR
fi

cd ~/apps
git clone http://github.com/sktelecom-oslab/armada.git && cd armada
OS_DISTRO=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}')
if [ $OS_DISTRO == Red ]; then
    sudo yum -y install https://rhel7.iuscommunity.org/ius-release.rpm
    sudo yum -y install python36u python36u-devel
    sudo yum install -y python36u-pip
    sudo pip3.6 install .
elif [ $OS_DISTRO == CentOS ]; then
    sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
    sudo yum -y install python36u python36u-devel
    sudo yum install -y python36u-pip
    sudo pip3.6 install .
elif [ $OS_DISTRO == Ubuntu ]; then
    sudo apt-get install -y python3-pip
    sudo pip3 install --upgrade pip==9.0.3
    sudo pip3 install .
else
    echo "This Linux Distribution is NOT supported"
fi
