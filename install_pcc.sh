#!/bin/bash


PUBLIC_HOST=$(ec2metadata --public-host)
ADMIN_USER="admin"

SECTION_LOG=/tmp/SECTION.log

SECTION_LOG() {
    if [ -z "$1" ]; then
        tee -a ${SECTION_LOG}
    else
        echo "$*" >> ${SECTION_LOG}
    fi
}

die() {
    echo "$0: die - $*" >&2 | SECTION_LOG
    exit 1
}

[ `id -un` != 'root' ] && die "$0: run as root"

UNPACK_TAR() {
    echo; echo "---- Unpacking tar [$PRISMA_PCC_TAR] -----"

    tar xvzf $PRISMA_PCC_TAR  -C ~/twistlock

    { echo; echo "---- Removing tar file to win back disk space:";
    df -h / ; echo "rm  -f $PRISMA_PCC_TAR"; rm  -f $PRISMA_PCC_TAR; df -h /;
    echo "----"
    } | SECTION_LOG
}

CREATE_CONSOLE() {
    echo; echo "---- Creating Prisma Console"

    . /root/.profile
set -x
    #./linux/twistcli console export kubernetes --service-type LoadBalancer
    #env | grep TW_A_K
    env | grep TW_A_K
    #[ ! -z "$TW_A_K" ] && TW_CONS_OPTS="--registry-token $TW_A_K"
    export TW_CONS_OPTS="--registry-token $TW_A_K"

    ./linux/twistcli console export kubernetes --registry-token "$TW_A_K" --service-type NodePort
    #./linux/twistcli console export kubernetes $TW_CONS_OPTS --service-type NodePort
#set +x

    [ ! -f twistlock_console.yaml ] && die "Failed to export console manifest"

    ls          -altr twistlock_console.yaml
    kubectl create -f twistlock_console.yaml | SECTION_LOG
}

CREATE_PV() {
    echo; echo "---- Creating Prisma Console PV"

    mkdir -p /nfs/general/twistlock-pv
    chmod 777 /nfs/general/twistlock-pv/
    cat > /tmp/twistlock-pv.yaml <<YAML_EOF
apiVersion: v1
kind: PersistentVolume
metadata:
    name: twistlock-pv
    labels:
        type: local
spec:
    capacity:
        storage: 100Gi
    accessModes:
    - ReadWriteMany
    - ReadWriteOnce
    hostPath:
        path: "/nfs/general/twistlock-pv"
YAML_EOF

    MISSING='
    annotations:
        volume.beta.kubernetes.io/mount-options: "nolock,noatime,bg"
	'

    PCC_REC='
apiVersion: v1
kind: PersistentVolume
metadata:
    name: twistlock-console
    labels:
        app-volume: twistlock-console
    annotations:
        volume.beta.kubernetes.io/mount-options: "nolock,noatime,bg"
'

    kubectl create -f /tmp/twistlock-pv.yaml | SECTION_LOG
}

GET_ADMIN_NODE_PORT() {
    kubectl -n twistlock get all

    kubectl get service -n twistlock
    #kubectl get service -w -n twistlock
    #NAME                TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                         AGE
    #twistlock-console   LoadBalancer   10.111.3.10   <pending>     8084:30357/TCP,8083:31707/TCP   27m

    kubectl get service -o wide -n twistlock
    kubectl get service -n twistlock -o custom-columns=P:.spec.ports[*]
    #kubectl get service -n twistlock -o custom-columns=P:.spec.ports[*]
    kubectl get service -n twistlock -o custom-columns=P:.spec.ports[*] | SECTION_LOG

    NODE_PORTS=$(kubectl get service -n twistlock -o custom-columns=P:.spec.ports[*].nodePort --no-headers)
    echo NODE_PORTS=$NODE_PORTS

    MASTER_PUBLIC_IP=$(ec2metadata --public-ipv4)
    echo MASTER_PUBLIC_IP=$MASTER_PUBLIC_IP

    PORT1=${NODE_PORTS%,*}
    PORT2=${NODE_PORTS#*,}
    #echo commication URL=https://${MASTER_PUBLIC_IP}:${PORT1}

    #echo Management URL=https://${MASTER_PUBLIC_IP}:${PORT2}
    URL=https://${PUBLIC_HOST}:${PORT2}
    echo PrismaCloud Console/Management URL=$URL | SECTION_LOG
    echo $URL > /tmp/PCC.console.url
    ADMIN_NODE_PORT=$PORT2

    #$ kubectl get service -o wide -n twistlock
    #NAME                TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                         AGE   SELECTOR
    #twistlock-console   LoadBalancer   10.111.3.10   <pending>     8084:30357/TCP,8083:31707/TCP   27m   name=twistlock-console

    # Enter access token (required for pulling the Console image):
    # Neither storage class nor persistent volume labels were provided, using cluster default behavior
    # Saving output file to /home/ubuntu/twistlock/twistlock_console.yaml
}

INIT_CONSOLE() {
    [ -z "$PRISMA_PCC_TAR" ] && die "$PRISMA_PCC_TAR env var is unset"
    [ -z "$TW_A_K"         ] && die "$TW_A_K env var is unset"

    ping -c 1 registry-auth.twistlock.com || die " Cant reach registry";
    UNPACK_TAR
    CREATE_PV
    CREATE_CONSOLE
    GET_ADMIN_NODE_PORT
    { CMD="kubectl -n twistlock describe pod"; echo "-- $CMD"; $CMD; } | grep -A 20 Events: | SECTION_LOG
}

CREATE_DEFENDER() {
    PUBLIC_HOST=$(ec2metadata --public-host)
    ADMIN_USER="admin"

    ./linux/twistcli defender export kubernetes --address https://${PUBLIC_HOST}:${ADMIN_NODE_PORT} --user $ADMIN_USER --cluster-address twistlock-console

    [ ! -f defender.yaml ] && die "Failed to export defender manifest"

    kubectl create -f defender.yaml | SECTION_LOG
}

[ $(id -un) != 'root' ] && die "$0: run as root"

mkdir -p /root/twistlock
cd       /root/twistlock

if [ "$1" = "--init-console" ];then
    INIT_CONSOLE
else
    GET_ADMIN_NODE_PORT
    CREATE_DEFENDER
fi


