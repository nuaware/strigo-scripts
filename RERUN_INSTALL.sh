

USER_DATA_LOG=/root/tmp/user-data.op

[   -f ${USER_DATA_LOG}         ] && cp -a $USER_DATA_LOG ${USER_DATA_LOG}.$(date +'%Y-%m-%d_%H-%M-%S')
[ ! -f ${USER_DATA_LOG}.initial ] && [ -f $USER_DATA_LOG ] && mv $USER_DATA_LOG ${USER_DATA_LOG}.initial

USER_IS_OWNER=""
[ "$1" = "-o" ]      && USER_IS_OWNER="1"
[ "$1" = "--owner" ] && USER_IS_OWNER="1"

TRY_RERUN() {
    bash -x /root/tmp/instance/user-data.txt > ${USER_DATA_LOG}.rerun 2>&1
    echo "tail -3 ${USER_DATA_LOG}:"; tail -3 ${USER_DATA_LOG} | sed 's/^/    /'
}

TRY_RERUN

while ! kubectl get nodes; do
    echo "[$(date)] Retrying install"
    TRY_RERUN
    sleep 5
done

echo "DONE"





