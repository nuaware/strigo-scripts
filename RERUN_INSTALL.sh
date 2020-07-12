#!/bin/bash

USER_DATA_LOG=/root/tmp/user-data.op

[   -f ${USER_DATA_LOG}         ] && cp -a $USER_DATA_LOG ${USER_DATA_LOG}.$(date +'%Y-%m-%d_%H-%M-%S')
[ ! -f ${USER_DATA_LOG}.initial ] && [ -f $USER_DATA_LOG ] && mv $USER_DATA_LOG ${USER_DATA_LOG}.initial

USER_IS_OWNER=""
[ "$1" = "-o" ]      && USER_IS_OWNER="1"
[ "$1" = "--owner" ] && USER_IS_OWNER="1"

TRY_RERUN() {
    bash -x /root/tmp/instance/user-data.txt |& tee ${USER_DATA_LOG}.rerun
    #bash -x /root/tmp/instance/user-data.txt > ${USER_DATA_LOG}.rerun 2>&1
    #echo "tail -30 ${USER_DATA_LOG}:"; tail -30 ${USER_DATA_LOG} | sed 's/^/    /'
}

LOOP() {
    while ! kubectl get nodes; do
        echo "[$(date)] Retrying install"
        TRY_RERUN
        sleep 5
    done
}

cat <<EOF
To rerun:
- On master node change /etc/hosts:
  - replace THIS_NODE by master
  - replace THIS_NODE_pub by master_pub
- On worker1 node change /etc/hosts:
  - replace THIS_NODE by worker1
  - replace THIS_NODE_pub by worker1_pub
  - Copy/paste both worker1 lines to /etc/hosts on master
- Then run this script
EOF

TRY_RERUN

kubectl get nodes

echo "DONE"





