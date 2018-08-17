#!/bin/bash
set -ex
HOST=~/sktelecom/host_test.txt
sed -n '1,/#worker/p' host_file.txt | sed "/#worker/d" > master_node
i=0
while read line
do
  IFS=' ' read -a array <<< $line
# master node
  
  hostname=$(echo ${array[0]})
  ip_address=$(echo ${array[1]})
  if [ $hostname != "#master" ]; then
     master_array[${i}]=$hostname
     echo $hostname
     echo "${master_array[${i}]} ip=$ip_address">>$HOST
     i=$((i+1))
  
  #cat /etc/hosts>etc_hosts
  #echo $ip_address $hostname>>etc_hosts
  #sudo mv etc_hosts /etc/hosts
  #ssh-copy-id $ip_address
  fi 
done < "master_node"
