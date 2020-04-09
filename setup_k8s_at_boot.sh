#!/bin/bash

CNI_YAMLS="https://docs.projectcalico.org/manifests/calico.yaml"
POD_CIDR="192.168.0.0/16"

#K8S_RELEASE="1.18.1"
K8S_RELEASE="1.18.0"

# TOODL move to user-data:
INSTALL_KUBELAB=1

cat > /root/.jupyter.profile <<EOF
export HOME=/root
export PATH=~/bin:$PATH
EOF

echo 'watch -n 2 "kubectl get nodes; echo; kubectl get ns; echo; kubectl -n kubelab -o wide get cm,pods"' >> /home/ubuntu/.bash_history
echo 'watch -n 2 "kubectl get nodes; echo; kubectl get ns; echo; kubectl -n kubelab -o wide get cm,pods"' >> /root/.bash_history
echo '. /root/.jupyter.profile; cd; echo HOME=$HOME' >> /root/.bash_history

export HOME=/root

ERROR() {
    echo "******************************************************"
    echo "** ERROR: $*"
    echo "******************************************************"
}

[ -z "$API_KEY" ] && ERROR "API_KEY is unset"
[ -z "$ORG_ID"  ] && ERROR "ORG_ID is unset"
[ -z "$OWNER_ID_OR_EMAIL" ] && ERROR "OWNER_ID_OR_EMAIL is unset"P

#export PRIVATE_IP=$(hostname -i)
export PRIVATE_IP=$(ec2metadata --local-ipv4)
export PUBLIC_IP=$(ec2metadata --public-ipv4)
export NODE_NAME="unset"

[ -z "$PRIVATE_IP" ] && ERROR "PRIVATE_IP is unset"P
[ -z "$PUBLIC_IP"  ] && ERROR "PUBLIC_IP is unset"P

SCRIPT_DIR=$(dirname $0)

echo "Checking for Events owned by '$OWNER_ID_OR_EMAIL'"

set_EVENT_WORKSPACE() {
    NODE_IDX=$($SCRIPT_DIR/get_workspaces_info.py -idx)

    EVENT=$($SCRIPT_DIR/get_workspaces_info.py -e)
    #[ "$EVENT" = "None" ] && { echo "DEBUG: env= ------------------------ "; env; env | sed 's/^/export /' > /tmp/env.rc; echo "--------------------------------"; sleep 30; }
    WORKSPACE=$($SCRIPT_DIR/get_workspaces_info.py -w)
    #WORKSPACE=$($SCRIPT_DIR/get_workspaces_info.py -W | sed -e 's/  */_/g')
}

START_DOCKER_plus() {
    systemctl start docker
    systemctl enable docker
    echo "root: docker ps"
    docker ps

    groupadd docker
    usermod -aG docker ubuntu
    echo "ubuntu: docker ps"
    sudo -u ubuntu docker ps
    echo "ubuntu: docker version"
    sudo -i docker version
    #newgrp docker
}

GET_LAB_RESOURCES() {
    # CAREFUL THIS WILL EXPOSE YOUR API_KEY/ORG_ID
    curl -H "Authorization: Bearer ${ORG_ID}:${API_KEY}" -H "Accept: application/json" -H "Content-Type: application/json" "https://app.strigo.io/api/v1/classes/${CLASSID}/resources" | jq . | tee /tmp/LAB_RESOURCES.json
}

GET_EVENTS() {
    curl -H "Authorization: Bearer ${ORG_ID}:${API_KEY}" -H "Accept: application/json" -H "Content-Type: application/json" "https://app.strigo.io/api/v1/events" | jq . | tee /tmp/EVENTS.json
}

KUBEADM_INIT() { # USE $POD_CIDR

    #kubeadm init --kubernetes-version=$K8S_RELEASE --pod-network-cidr=$POD_CIDR --apiserver-cert-extra-sans=__MASTER1_IP__ | tee kubeadm-init.out
    export NODE_NAME="master"
    kubeadm init --node-name $NODE_NAME --pod-network-cidr=$POD_CIDR --kubernetes-version=$K8S_RELEASE \
                 --apiserver-cert-extra-sans=$PUBLIC_IP | \
        tee kubeadm-init.out
    #kubeadm init | tee /tmp/kubeadm-init.out
}

KUBEADM_JOIN() {

    NUM_NODES=$($SCRIPT_DIR/get_workspaces_info.py -nodes)

    JOIN_COMMAND=$(kubeadm token create --print-join-command)

    let WORKER_NUM=NUM_NODES-NUM_MASTERS
    for WORKER in $(seq $WORKER_NUM); do
        let NODE_NUM=NUM_MASTERS+WORKER-1
        WORKER_NODE_NAME="worker$WORKER"

        WORKER_IPS=$($SCRIPT_DIR/get_workspaces_info.py -ips $NODE_NUM)
        WORKER_PRIVATE_IP=${WORKER_IPS%,*};
        WORKER_PUBLIC_IP=${WORKER_IPS#*,};

        echo "WORKER[$WORKER]=NODE[$NODE_NUM] $WORKER_NODE_NAME WORKER_PRIVATE_IP=$WORKER_PRIVATE_IP WORKER_PUBLIC_IP=$WORKER_PUBLIC_IP"

	_SSH_IP="sudo -u ubuntu ssh -o StrictHostKeyChecking=no $WORKER_PRIVATE_IP"
        while ! $_SSH_IP uptime; do sleep 2; echo "Waiting for successful Worker$WORKER ssh conection ..."; done

        CMD="$_SSH_IP sudo $JOIN_COMMAND --node-name $WORKER_NODE_NAME"
        echo "-- $CMD"
        $CMD
        echo $WORKER_NODE_NAME | $_SSH_IP tee /tmp/NODE_NAME
    done
}

CNI_INSTALL() {
    kubectl get nodes

    for CNI_YAML in $CNI_YAMLS; do
        kubectl create -f $CNI_YAML
    done
    kubectl get nodes
    kubectl get pods -n kube-system

    echo "NEED TO WAIT - HOW TO HANDLE failure ... need to restart coredns, other?"
}

SETUP_KUBECONFIG() {
    #export KUBECONFIG=/etc/kubernetes/admin.conf
    export ADMIN_KUBECONFIG=/etc/kubernetes/admin.conf

    mkdir -p /root/.kube
    cp -a $ADMIN_KUBECONFIG /root/.kube/config
    echo "root: kubectl get nodes:"
    kubectl get nodes

    mkdir -p /home/ubuntu/.kube
    cp -a $ADMIN_KUBECONFIG /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    echo "ubuntu: kubectl get nodes:"
    #sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl get nodes
    sudo -u ubuntu kubectl get nodes
}

KUBECTL_VERSION() {
    kubectl version -o yaml
}

INSTALL_KUBELAB() {
    mkdir -p /root/github.com
    git clone https://github.com/mjbright/kubelab /root/github.com/kubelab

    cat > /tmp/kubelab.sh << EOF

# Create modified config.kubelab
# - needed so kubectl in cluster will use 'default' namespace not 'kubelab':
#
# TODO: add note in kubelab/README.md
# TODO: Match on/modify after context name

export KUBECONFIG=/etc/kubernetes/admin.conf

sed -e '/user: kubernetes-admin/a \ \ \ \ namespace: default' < /home/ubuntu/.kube/config  > /home/ubuntu/.kube/config.kubelab
chown ubuntu:ubuntu /home/ubuntu/.kube/config.kubelab

# Mount new kubeconfig as a ConfigMap/file:
kubectl create ns kubelab 
kubectl -n kubelab create configmap kube-configmap --from-file=/home/ubuntu/.kube/config.kubelab

kubectl create -f /root/github.com/kubelab/kubelab.yaml

kubectl -n kubelab get cm
kubectl -n kubelab get pods -o wide | grep " Running " || sleep 10
kubectl -n kubelab get pods -o wide | grep " Running " || sleep 10
kubectl -n kubelab get pods -o wide | grep " Running " || sleep 10

kubectl -n kubelab cp /root/.jupyter.profile kubelab:.profile
EOF

    chmod +x /tmp/kubelab.sh
    /tmp/kubelab.sh
}

REGISTER_INSTALL() {
    wget -qO - "$REGISTER_URL/${EVENT}_${WORKSPACE}_${NODE_NAME}_${PUBLIC_IP}"
}

SECTION() {
    SECTION="$*"

    echo; echo "============ $SECTION ================================="
    $*
}

NUM_MASTERS=1

apt-get update && apt-get install -y jq

id -un

#ping -c 1 $LAB_Virtual_Machine_1_PRIVATE_IP #ping -c 1 $LAB_Virtual_Machine_2_PRIVATE_IP 
#sudo -u ubuntu ssh -o StrictHostKeyChecking=no $LAB_Virtual_Machine_1_PRIVATE_IP  uptime
SECTION START_DOCKER_plus
# SECTION GET_LAB_RESOURCES - CAREFUL THIS WILL EXPOSE YOUR API_KEY/ORG_ID

set_EVENT_WORKSPACE
[ -z "$NODE_IDX"  ] && {
    ERROR "NODE_IDX is unset"
}

# Perform all kubeadm operations from Master1:
if [ $NODE_IDX -eq 0 ] ; then
    SECTION KUBEADM_INIT
    SECTION SETUP_KUBECONFIG
    SECTION CNI_INSTALL
    SECTION KUBEADM_JOIN
    SECTION KUBECTL_VERSION
    [ $INSTALL_KUBELAB -ne 0 ] && SECTION INSTALL_KUBELAB
else
    while [ ! -f /tmp/NODE_NAME ]; do sleep 5; done
    NODE_NAME=$(cat /tmp/NODE_NAME)
fi

[ ! -z "$REGISTER_URL" ] && SECTION REGISTER_INSTALL



