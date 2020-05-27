#!/bin/bash

APT_INSTALLS() {
    #sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y tmux curl vim && sudo apt-get clean && sudo apt-get autoclean
    apt-get update && apt-get upgrade -y && apt-get install -y tmux curl vim python3-pip
}

PIP_INSTALLS() {
    python3 -m pip install --upgrade pip && \
    python3 -m pip install setuptools && \
    python3 -m pip install pick ppretty && \
    python3 -m pip install RISE && \
    python3 -m pip install kubernetes && \
    python3 -m pip install jupyter_nbextensions_configurator && \
    python3 -m pip install --no-cache-dir bash_kernel
}

ENABLE_JUPYTER_BASH() {
    echo; echo "---- jupyter nbextensions_configurator enable --system"
    jupyter nbextensions_configurator enable --system
    echo; echo "---- sudo -u $END_USER HOME=/home/$END_USER python3 -m bash_kernel.install"
    sudo -u $END_USER HOME=/home/$END_USER python3 -m bash_kernel.install
    echo
}

END_USER=${USERS% *}
END_USER=${END_USER%:*}
#echo $END_USER

APT_INSTALLS
PIP_INSTALLS
ENABLE_JUPYTER_BASH

cat > /tmp/jupyter.sh <<EOF
#!/bin/bash

if [[ "$1" = "-fg" ]]; then
    shift
else
    ( "$0" -fg "$@" </dev/null &>/dev/null & )
    exit
fi

exec > /tmp/jupyter.log 2>&1
echo "Logging jupyter output to /tmp/jupyter.log"

while true; do
    #jupyter notebook --port 8888 --ip=0.0.0.0 --allow-root --no-browser
    jupyter notebook --port 8888 --ip=127.0.0.1 --allow-root --no-browser
done

EOF

chmod +x /tmp/jupyter.sh
echo "Starting Jupyter using: /tmp/jupyter.sh"
echo "Look for token in:   /tmp/jupyter.log"
/tmp/jupyter.sh

echo "Setup ssh tunnel to open port $(ec2metadata --public-host):8888 to localhost:8888"

exit 0

