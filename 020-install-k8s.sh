#!/bin/bash

set -ex
export PATH=$PATH:/usr/local/bin
cd ~/

mkdir -p ~/apps

UPSTREAM_KUBESPRAY_DIR=~/apps/upstream-kubespray
if [ -d $UPSTREAM_KUBESPRAY_DIR ]; then
  rm -rf $UPSTREAM_KUBESPRAY_DIR
fi

cd ~/apps
git clone https://github.com/kubernetes-incubator/kubespray.git upstream-kubespray && cd upstream-kubespray
git checkout -b branch_v2.6.0 tags/v2.6.0
#if tag="master"; then
   
#defalut = 2.6.0

sudo pip install -r requirements.txt

new_taco=~/apps/upstream-kubespray/inventory/new_version_TACO
mkdir -p $new_taco
cp -r ~/apps/upstream-kubespray/inventory/sample $new_taco
HOST=~/apps/upstream-kubespray/inventory/new_version_TACO/hosts.ini

echo "******** You have to make host information file named \"host_file.txt\" ********"

sed -n '1,/#worker/p' ~/sktelecom/host_file.txt | sed "/#worker/d" > master_node
# sed -e '/^$/'d를 넣는게 더 안전할것 같아 확인후 넣기 
# if folder is changed , the address name 'sktelecom' have to change
i=0

while read line
do
  IFS=' ' read -a array <<< $line
  #for setting master nodes
  hostname=$(echo ${array[0]})
  ip_address=$(echo ${array[1]})
  if [ $hostname != "#master" ]; then
      master_array[${i}]=$hostname
      echo "${master_array[${i}]} ip=$ip_address">>$HOST
      i=$((i+1))

      cat /etc/hosts>etc_hosts
      echo $ip_address $hostname>>etc_hosts
      sudo mv etc_hosts /etc/hosts
      ssh-copy-id $ip_address
  fi 
done < "master_node"
  
sed -n '/#worker/,/end/p' ~/sktelecom/host_file.txt | sed "/end/d" > worker_node
i=0
while read line
do
  IFS=' ' read -a array <<< $line
  #for setting worker nodes
    
  hostname=$(echo ${array[0]})
  ip_address=$(echo ${array[1]})
  if [ $hostname != "#worker" ]; then
      worker_array[${i}]=$hostname
      echo "${worker_array[${i}]} ip=$ip_address">>$HOST
      i=$((i+1))

      cat /etc/hosts>etc_hosts
      echo $ip_address $hostname>>etc_hosts
      sudo mv etc_hosts /etc/hosts
      ssh-copy-id $ip_address
  fi 
done < "worker_node"

rm master_node && rm worker_node 

# edit nameserver 
cat /etc/resolv.conf > resolv_config
echo "nameserver 8.8.8.8">resolv_config
sudo mv resolv_config /etc/resolv.conf

echo "[kube-master]">>$HOST
for arr_item in ${master_array[*]}
do
  echo $arr_item >>$HOST
done

echo "[etcd]">>$HOST
for arr_item in ${master_array[*]}; do
  echo $arr_item >>$HOST
done

echo "[kube-node]">>$HOST
for arr_item in ${master_array[*]}; do
  echo $arr_item >>$HOST
done
for arr_item in ${worker_array[*]}; do
  echo $arr_item >>$HOST
done

echo """[k8s-cluster:children]
kube-node
kube-master""">>$HOST

echo "[controller-node]">>$HOST
for arr_item in ${master_array[*]}; do
  echo $arr_item >>$HOST
done

echo "[compute-node]">>$HOST
for arr_item in ${worker_array[*]}; do
  echo $arr_item >>$HOST
done
echo """[controller-node:vars]
node_labels={\"openstack-control-plane\":\"enabled\",\"openvswitch\":\"enabled\"}
[compute-node:vars]
node_labels={\"openstack-compute-node\":\"enabled\",\"openvswitch\":\"enabled\"}""" >>$HOST

sudo apt remove python3

ansible-playbook -u ubuntu -b -i ~/apps/upstream-kubespray/inventory/new_version_TACO/hosts.ini --extra-vars=~/sktelecom/extra-vars.yaml ~/apps/upstream-kubespray/cluster.yml

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | cat > /tmp/helm_script.sh \
&& chmod 755 /tmp/helm_script.sh && /tmp/helm_script.sh --version v2.9.1

cat /etc/resolv.conf > resolv_config
echo """nameserver 10.96.0.10
nameserver 8.8.8.8
nameserver 8.8.4.4
search openstack.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
options timeout:1""" >resolv_config
sudo mv resolv_config /etc/resolv.conf

set -e

# From Kolla-Kubernetes, orginal authors Kevin Fox & Serguei Bezverkhi
# Default wait timeout is 600 seconds
end=$(expr $(date +%s) + 600)
while true; do
    kubectl get pods --namespace=kube-system -o json | jq -r \
        '.items[].status.phase' | grep Pending > /dev/null && \
        PENDING=True || PENDING=False
    query='.items[]|select(.status.phase=="Running")'
    query="$query|.status.containerStatuses[].ready"
    kubectl get pods --namespace=kube-system -o json | jq -r "$query" | \
        grep false > /dev/null && READY="False" || READY="True"
    kubectl get jobs -o json --namespace=kube-system | jq -r \
        '.items[] | .spec.completions == .status.succeeded' | \
        grep false > /dev/null && JOBR="False" || JOBR="True"
    [ $PENDING == "False" -a $READY == "True" -a $JOBR == "True" ] && \
        break || true
    sleep 5
    now=$(date +%s)
    [ $now -gt $end ] && echo containers failed to start. && \
        kubectl get pods --namespace kube-system -o wide && exit -1
done
