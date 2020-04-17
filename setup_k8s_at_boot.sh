#!/bin/bash

CNI_YAMLS="https://docs.projectcalico.org/manifests/calico.yaml"
POD_CIDR="192.168.0.0/16"

#K8S_RELEASE="1.18.1"
K8S_RELEASE="1.18.0"
K8S_INSTALLER="kubeadm"

#K8S_INSTALLER="rancher"
#RANCHER_RKE_RELEASE="v1.0.6"

#BIN=/root/bin
BIN=/usr/local/bin

# TODO: move to user-data:
INSTALL_KUBELAB=1

# TODO: move to user-data: (only download for workshops)
DOWNLOAD_PCC_TWISTLOCK=1
INSTALL_PCC_TWISTLOCK=0
[ ! -z "$TW_A_K" ] && echo "export TW_A_K=$TW_A_K" >> /root/.profile

# Terraform
INSTALL_TERRAFORM=1

# Helm
INSTALL_HELM=1

cat >> /root/.profile <<EOF
export HOME=/root
export PATH=~/bin:$PATH
EOF

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

die() {
    ERROR $*
    echo "$0: die - Installation failed" >&2
    echo $* >&2
    exit 1
}

[ -z "$API_KEY" ] && die "API_KEY is unset"
[ -z "$ORG_ID"  ] && die "ORG_ID is unset"
[ -z "$OWNER_ID_OR_EMAIL" ] && die "OWNER_ID_OR_EMAIL is unset"P

#export PRIVATE_IP=$(hostname -i)
export PRIVATE_IP=$(ec2metadata --local-ipv4)
export PUBLIC_IP=$(ec2metadata --public-ipv4)
export NODE_NAME="unset"

[ -z "$PRIVATE_IP" ] && die "PRIVATE_IP is unset"P
[ -z "$PUBLIC_IP"  ] && die "PUBLIC_IP is unset"P

SCRIPT_DIR=$(dirname $0)

echo "Checking for Events owned by '$OWNER_ID_OR_EMAIL'"

set_EVENT_WORKSPACE_NODES() {
    [ -z "$NUM_NODES" ] && die "Expected number of nodes is not set/exported from invoking user-data script"

    _NUM_NODES=$($SCRIPT_DIR/get_workspaces_info.py -nodes)
    while [ $_NUM_NODES -lt $NUM_NODES ]; do
        echo "[ '$_NUM_NODES' -lt '$NUM_NODES' ] - waiting for more nodes to become available ..."
	sleep 2
        _NUM_NODES=$($SCRIPT_DIR/get_workspaces_info.py -nodes)
        [ -z "$_NUM_NODES" ] && _NUM_NODES=0
    done

    let NUM_WORKERS=NUM_NODES-NUM_MASTERS

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

RANCHER_RKE_INIT() { # USE $POD_CIDR

    FILE=$BIN/rke
    URL=https://github.com/rancher/rke/releases/download/${RANCHER_RKE_RELEASE}/rke_linux-amd64
    wget -qO $BIN/rke $URL
}

KUBEADM_INIT() { # USE $POD_CIDR

    #kubeadm init --kubernetes-version=$K8S_RELEASE --pod-network-cidr=$POD_CIDR --apiserver-cert-extra-sans=__MASTER1_IP__ | tee kubeadm-init.out
    export NODE_NAME="master"
    kubeadm init --node-name $NODE_NAME --pod-network-cidr=$POD_CIDR --kubernetes-version=$K8S_RELEASE \
                 --apiserver-cert-extra-sans=$PUBLIC_IP | \
        tee /tmp/kubeadm-init.out
    #kubeadm init | tee /tmp/kubeadm-init.out
}

# Configure nodes access from master:
# - Add entries to /etc/hosts
# - Create .ssh/config entries
#
CONFIG_NODES_ACCESS() {
    echo "$PRIVATE_IP master" | tee /tmp/hosts.add

    WORKER_PRIVATE_IPS=""
    for WORKER in $(seq $NUM_WORKERS); do
        WORKER_IPS=$($SCRIPT_DIR/get_workspaces_info.py -ips $NODE_NUM)
        WORKER_PRIVATE_IP=${WORKER_IPS%,*};
        WORKER_PUBLIC_IP=${WORKER_IPS#*,};
        WORKER_PRIVATE_IPS+="$WORKER_PRIVATE_IP"
	echo "$WORKER_PRIVATE_IP $WORKER_NODE_NAME" | tee -a /tmp/hosts.add
        mkdir -p ~/.ssh
        mkdir -p /home/ubuntu/.ssh
        touch /home/ubuntu/.ssh/config
        chown ubuntu:ubuntu /home/ubuntu/.ssh/config
	{
            echo ""
            echo "Host $WORKER_NODE_NAME"
	    echo "    User     ubuntu"
	    echo "    Hostname $WORKER_PRIVATE_IP"
	    echo "    IdentityFile ~/.ssh/id_rsa"
        } | tee -a ~/.ssh/config | tee -a /home/ubuntu/.ssh/config

        echo "WORKER[$WORKER]=NODE[$NODE_NUM] $WORKER_NODE_NAME WORKER_PRIVATE_IP=$WORKER_PRIVATE_IP WORKER_PUBLIC_IP=$WORKER_PUBLIC_IP"

        WORKER_IPS=$($SCRIPT_DIR/get_workspaces_info.py -ips $NODE_NUM)
        WORKER_PRIVATE_IP=${WORKER_IPS%,*};
        WORKER_PUBLIC_IP=${WORKER_IPS#*,};
        WORKER_PRIVATE_IPS+="$WORKER_PRIVATE_IP"

	_SSH_IP="sudo -u ubuntu ssh -o StrictHostKeyChecking=no $WORKER_PRIVATE_IP"
        while ! $_SSH_IP uptime; do sleep 2; echo "Waiting for successful Worker$WORKER ssh conection ..."; done
    done

    echo; echo "-- setting up /etc/hosts"
    cat /tmp/hosts.add >> /etc/hosts
    for WORKER in $(seq $NUM_WORKERS); do
        ssh $WORKER_NODE_NAME "sudo cat /tmp/hosts.add >> /etc/hosts"
    done
}

KUBEADM_JOIN() {
    JOIN_COMMAND=$(kubeadm token create --print-join-command)

    echo; echo "-- performing join command on worker nodes"
    for WORKER in $(seq $NUM_WORKERS); do
        let NODE_NUM=NUM_MASTERS+WORKER-1
        WORKER_NODE_NAME="worker$WORKER"

        #CMD="$_SSH_IP sudo $JOIN_COMMAND --node-name $WORKER_NODE_NAME"
        CMD="ssh $WORKER_NODE_NAME sudo $JOIN_COMMAND --node-name $WORKER_NODE_NAME"
        echo "-- $CMD"
        $CMD
        echo $WORKER_NODE_NAME | ssh $WORKER_NODE_NAME /tmp/NODE_NAME
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

set -x

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

INSTALL_PCC_TWISTLOCK() {
    echo TODO
}

INSTALL_HELM() {
    RELEASE="v3.1.2"
    TAR_GZ="/tmp/helm.${RELEASE}.tar.gz"
    URL="https://get.helm.sh/helm-${RELEASE}-linux-amd64.tar.gz"

    wget -qO $TAR_GZ $URL

    mkdir -p   $BIN
    tar xf $TAR_GZ -C $BIN --strip-components 1 linux-amd64/helm

    helm repo add stable https://kubernetes-charts.storage.googleapis.com/

    #helm search hub ingress-nginx
    #helm install hub stable/nginx-ingress
    #kubectl create ns nginx-ingress; helm install -n nginx-ingress hub stable/nginx-ingress

    #helm search hub redis
    #kubectl create ns redis
    #helm install -n redis hub stable/redis-ha

    #helm search hub traefik
    #helm install hub stable/traefik



}

INSTALL_TERRAFORM() {
    RELEASE="0.12.24"

    ZIP=/tmp/terraform.${RELEASE}.zip
    URL="https://releases.hashicorp.com/terraform/${RELEASE}/terraform_${RELEASE}_linux_amd64.zip"

    wget -qO $ZIP $URL

    mkdir -p   $BIN/
    unzip $ZIP -d $BIN terraform
}

DOWNLOAD_PCC_TWISTLOCK() {
    #https://cdn.twistlock.com/releases/6e6c2d6a/prisma_cloud_compute_edition_20_04_163.tar.gz
    TWISTLOCK_PCC_RELEASE=20_04_163

    TAR="/tmp/prisma_cloud_compute_edition_${TWISTLOCK_PCC_RELEASE}.tar.gz"
    URL="https://cdn.twistlock.com/releases/6e6c2d6a/prisma_cloud_compute_edition_${TWISTLOCK_PCC_RELEASE}.tar.gz"

    wget -O $TAR $URL
}

REGISTER_INSTALL_START() {
    wget -qO - "$REGISTER_URL/${EVENT}_${WORKSPACE}_${NODE_NAME}_${PUBLIC_IP}_provisioning_START"
}

REGISTER_INSTALL_END() {
    wget -qO - "$REGISTER_URL/${EVENT}_${WORKSPACE}_${NODE_NAME}_${PUBLIC_IP}_provisioning_END"
}

SECTION() {
    SECTION="$*"

    echo; echo "============ $SECTION ================================="
    $*
}

NUM_MASTERS=1

apt-get update && apt-get install -y jq zip

id -un

#ping -c 1 $LAB_Virtual_Machine_1_PRIVATE_IP #ping -c 1 $LAB_Virtual_Machine_2_PRIVATE_IP 
#sudo -u ubuntu ssh -o StrictHostKeyChecking=no $LAB_Virtual_Machine_1_PRIVATE_IP  uptime
SECTION START_DOCKER_plus
# SECTION GET_LAB_RESOURCES - CAREFUL THIS WILL EXPOSE YOUR API_KEY/ORG_ID

set_EVENT_WORKSPACE_NODES
[ -z "$NODE_IDX"  ] && {
    die "NODE_IDX is unset"
}

INSTALL_KUBERNETES() {
    case $K8S_INSTALLER in
        "kubeadm")
            SECTION KUBEADM_INIT
            SECTION SETUP_KUBECONFIG
            SECTION CNI_INSTALL
            SECTION KUBEADM_JOIN
            SECTION KUBECTL_VERSION
        ;;
        "rancher")
            SECTION RANCHER_INIT
        ;;
        *)
        ;;
    esac
}

# TODO: setup NFS share across nodes
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nfs-mount-on-ubuntu-18-04
SETUP_NFS() {
    NODE_TYPE=$1; shift

    echo "Firewall(ufw status): $( ufw status )"

    case $NODE_TYPE in
        master)
            apt-get install -y nfs-kernel-server
	    mkdir -p /var/nfs/general /nfs
	    chown nobody:nogroup /var/nfs/general

	    for WIP in $WORKER_PRIVATE_IPS; do
                echo "/var/nfs/general    $WIP(rw,sync,no_subtree_check)"
	        #/home       $PIP(rw,sync,no_root_squash,no_subtree_check)
	    done | tee -a /etc/exports

	    systemctl restart nfs-kernel-server
	    ln -s /var/nfs/general /nfs/

	    ;;
        *)
            apt-get install -y nfs-common
	    mkdir -p /nfs/general
	    mount master:/var/nfs/general /nfs/general
	    ;;
    esac
}

[ ! -z "$REGISTER_URL" ] && SECTION REGISTER_INSTALL_START

# Perform all kubeadm operations from Master1:
if [ $NODE_IDX -eq 0 ] ; then
    SECTION CONFIG_NODES_ACCESS
    SECTION INSTALL_KUBERNETES
    [ $INSTALL_KUBELAB -ne 0 ]        && SECTION INSTALL_KUBELAB
    [ $DOWNLOAD_PCC_TWISTLOCK -ne 0 ] && SECTION DOWNLOAD_PCC_TWISTLOCK
    [ $INSTALL_PCC_TWISTLOCK -ne 0 ]  && SECTION INSTALL_PCC_TWISTLOCK
    [ $INSTALL_TERRAFORM -ne 0 ]      && SECTION INSTALL_TERRAFORM
    [ $INSTALL_HELM -ne 0 ]           && SECTION INSTALL_HELM
    SECTION SETUP_NFS master
else
    while [ ! -f /tmp/NODE_NAME ]; do sleep 5; done
    NODE_NAME=$(cat /tmp/NODE_NAME)
    SECTION SETUP_NFS worker
fi

[ ! -z "$REGISTER_URL" ] && SECTION REGISTER_INSTALL_END



