#!/bin/bash

APT_INSTALLS() {
    #sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y tmux curl vim && sudo apt-get clean && sudo apt-get autoclean
    sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y tmux curl vim python3-pip
}

PIP_INSTALLS() {
    pip3 install --upgrade pip && \
    pip3 install setuptools && \
    pip3 install pick ppretty && \
    pip3 install RISE && \
    pip3 install kubernetes && \
    pip3 install jupyter_nbextensions_configurator && \
    pip3 install --no-cache-dir bash_kernel
}

ENABLE_JUPYTER_BASH() {
    jupyter nbextensions_configurator enable --system
    python3 -m bash_kernel.install
}


APT_INSTALLS
PIP_INSTALLS
ENABLE_JUPYTER_BASH

cat > /tmp/jupyter.sh <<EOF
#!/bin/bash

exec > /tmp/jupyter.log 2>&1
echo "Logging jupyter output to /tmp/jupyter.log"

while true; do
    #jupyter notebook --port 8888 --ip=0.0.0.0 --allow-root --no-browser
    jupyter notebook --port 8888 --ip=127.0.0.1 --allow-root --no-browser
done

EOF

chmod +x /tmp/jupyter.sh
echo "Start Jupyter using: /tmp/jupyter.sh"
echo "Look for token in:   /tmp/jupyter.log"

echo "Setup ssh tunnel to open port $(ec2metadata --public-host):8888 to localhost:8888"

exit 0

