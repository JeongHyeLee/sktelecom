#!/bin/bash
set -ex
export PATH=$PATH:/usr/local/bin
cd ~/

mkdir -p ~/apps
TACO_KUBESPRAY_DIR=~/apps/taco-kubespray
if [ -d $TACO_KUBESPRAY_DIR ]; then
  rm -rf $TACO_KUBESPRAY_DIR
fi

UPSTREAM_KUBESPRAY_DIR=~/apps/upstream-kubespray
if [ -d $UPSTREAM_KUBESPRAY_DIR ]; then
  rm -rf $UPSTREAM_KUBESPRAY_DIR
fi

KUBESPRAY_DIR=~/apps/kubespray
if [ -d $KUBESPRAY_DIR ]; then
  rm -rf $KUBESPRAY_DIR
fi

CACHE_FILE=/tmp/taco-aio
if [ -f $CACHE_FILE ]; then
  rm -f $CACHE_FILE
fi

cd ~/apps
git clone https://github.com/kubernetes-incubator/kubespray.git upstream-kubespray && cd upstream-kubespray
sudo pip install -r requirements.txt

HOST=~/apps/upstream-kubespray/inventory/sample/hosts.ini

ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""

echo "[enter the hostname that you want to use as master and worker node and ip address respectively]"
read -p "****how many \"masters\" : " number
for i in $(seq $number); do
   read  -p "#${i} input master node's <hostname> <ip-address> :" hostname ip_address
   master_array[${i}-1]=$hostname
   echo $hostname ip=$ip_address>>$HOST
   cat /etc/hosts>etc_hosts
   echo $ip_address $hostname>>etc_hosts
   sudo mv etc_hosts /etc/hosts
   ssh-copy-id $ip_address
done

read -p "****how many \"workers\" : " number
for i in $(seq $number); do
   read  -p "#${i} input worker node's <hostname> <ip-address> :" hostname ip_address
   worker_array[${i}-1]=$hostname
   echo $hostname ip=$ip_address>>$HOST
   cat /etc/hosts>etc_hosts
   echo $ip_address $hostname>>etc_hosts
   sudo mv etc_hosts /etc/hosts
   ssh-copy-id $ip_address
done

# if the information is in file
# not yet

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
node_labels={\"openstack-control-plane\":\"enabled\", \"openvswitch\":\"enabled\"}
[compute-node:vars]
node_labels={\"openstack-compute-node\":\"enabled\", \"openvswitch\":\"enabled\"}""" >>$HOST

ansible-playbook -u ubuntu -b -i ~/apps/upstream-kubespray/inventory/sample/hosts.ini --extra-vars=~/sktelecom/extra-vars.yaml ~/apps/upstream-kubespray/cluster.yml

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | cat > /tmp/helm_script.sh \
&& chmod 755 /tmp/helm_script.sh && /tmp/helm_script.sh --version v2.9.1

#echo """nameserver 10.96.0.10
#nameserver 8.8.8.8
#nameserver 8.8.4.4
#search openstack.svc.cluster.local svc.cluster.local cluster.local
#options ndots:5""" > /etc/resolv.conf

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
