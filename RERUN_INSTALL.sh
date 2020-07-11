

USER_DATA_LOG=/root/tmp/user-data.op

[   -f ${USER_DATA_LOG}         ] && cp -a $USER_DATA_LOG ${USER_DATA_LOG}.$(date +'%Y-%m-%d_%H-%M-%S')
[ ! -f ${USER_DATA_LOG}.initial ] && [ -f $USER_DATA_LOG ] && mv $USER_DATA_LOG ${USER_DATA_LOG}.initial

USER_IS_OWNER=""
[ "$1" = "-o" ]      && USER_IS_OWNER="1"
[ "$1" = "--owner" ] && USER_IS_OWNER="1"

bash -x /root/tmp/instance/user-data.txt > ${USER_DATA_LOG}.rerun 2>&1

while ! kubectl get nodes; do
    echo "[$(date)] Retrying install"
    bash -x /root/tmp/instance/user-data.txt > ${USER_DATA_LOG}.rerun 2>&1
done

echo "DONE"





