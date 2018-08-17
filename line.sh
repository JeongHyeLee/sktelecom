#!/bin/bash

while read line
do
  IFS=' ' read -a array <<< $line
  hostname=$(echo ${array[0]})
  ip_address=$(echo ${array[1]})
  #echo $hostname
  #echo $ip_address

done < "host_file.txt"
i=3
sed -n '2,/#worker/p' host_file.txt
