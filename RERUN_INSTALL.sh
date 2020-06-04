

[ ! -f /root/tmp/user-data.op.initial ] && mv /root/tmp/user-data.op /root/tmp/user-data.op.initial

bash -x /root/tmp/instance/user-data.txt > /root/tmp/user-data.op.rerun 2>&1



