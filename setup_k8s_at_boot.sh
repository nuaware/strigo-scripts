#!/bin/bash

exec > /tmp/user-data.op 2>&1

env

CNI_YAMLS="https://docs.projectcalico.org/manifests/calico.yaml"
POD_CIDR="192.168.0.0/16"

apt-get update && apt-get install -y jq

id -un

#ping -c 1 $LAB_Virtual_Machine_1_PRIVATE_IP #ping -c 1 $LAB_Virtual_Machine_2_PRIVATE_IP 
#sudo -u ubuntu ssh -o StrictHostKeyChecking=no $LAB_Virtual_Machine_1_PRIVATE_IP  uptime

START_DOCKER_plus() {
    systemctl start docker
    systemctl enable docker
    docker ps

    groupadd docker
    usermod -aG docker $USER
    sudo -u ubuntu docker ps
    #newgrp docker
}

#TODO: SET #- MASTER1 #- WORKER1
GET_LAB_RESOURCES() {
    curl -H "Authorization: Bearer ${ORG_ID}:${API_KEY}" -H "Accept: application/json" -H "Content-Type: application/json" "https://app.strigo.io/api/v1/classes/${CLASSID}/resources" | jq . | tee /tmp/LAB_RESOURCES.json
}

GET_EVENTS() {
    curl -H "Authorization: Bearer ${ORG_ID}:${API_KEY}" -H "Accept: application/json" -H "Content-Type: application/json" "https://app.strigo.io/api/v1/events" | jq . | tee /tmp/EVENTS.json
}

KUBEADM_INIT() { # USE $POD_CIDR
    #kubeadm init --kubernetes-version=$K8S_RELEASE --pod-network-cidr=$POD_CIDR --apiserver-cert-extra-sans=__MASTER1_IP__ | tee kubeadm-init.out
    #kubeadm init --pod-network-cidr=$POD_CIDR --apiserver-cert-extra-sans=$(ec2metadata --public-ip) | tee kubeadm-init.out
    kubeadm init | tee /tmp/kubeadm-init.out
}

KUBEADM_JOIN() {
    IP=$1

    JOIN_COMMAND=$(kubeadm token create --print-join-command)

    echo $JOIN_COMMAND 
    sudo -u ubuntu ssh $WORKER1 $JOIN_COMMAND
}

CNI_INSTALL() {
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl get nodes

    for CNI_YAML in CNI_YAMLS; do
        kubectl create -f $CNI_YAML
    done
    kubectl get nodes
    kubectl get pods -n kube-system

    echo "NEED TO WAIT - HOW TO HANDLE failure ... need to restart coredns, other?"
}

SETUP_KUBECONFIG() {

    mkdir -p /home/ubuntu/.kube
    cp -a $KUBECONFIG /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    #sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl get nodes
    sudo -u ubuntu kubectl get nodes
}

SECTION() {
    SECTION="$*"

    echo; echo "============ $SECTION ================================="
    $*
}

SECTION START_DOCKER_plus
SECTION GET_LAB_RESOURCES
SECTION KUBEADM_INIT
SECTION KUBEADM_JOIN
SECTION CNI_INSTALL
SECTION SETUP_KUBECONFIG

