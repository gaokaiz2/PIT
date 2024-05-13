#!/bin/bash
set -ex

# Log output of this script to /var/log/syslog.
# https://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

PROJ_GROUP="$1"

# whoami
echo "Running as $(whoami)"

# # i am root now
# if [[ $EUID -ne 0 ]]; then
#     echo "Escalating to root with sudo"
#     exec sudo /bin/bash "$0" "$@"
# fi

# install dgl and pytorch after reboot
if [ -d "/opt/miniconda" ]; then
    nvidia-smi
    
    # pytorch 2.1 with cuda 12.1
    sudo chmod a+rw -R /opt/miniconda # double ensure write permission
    conda install -y pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia

    # base GPU software
    pip3 install --upgrade nvitop
    echo 'alias nv=nvitop' >> "$HOME/.bashrc"

    pip install requests torchmetrics==0.11.4
    pip install tensorboard

    echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.bashrc"

    echo 'conda activate llama' >> "$HOME/.bashrc"

    source "$HOME/.bashrc"
    python ./archive/test_env.py

    exit
fi

function install_cuda_12_1() {
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.1.0/local_installers/cuda-repo-ubuntu2204-12-1-local_12.1.0-530.30.02-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2204-12-1-local_12.1.0-530.30.02-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2204-12-1-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda
    sudo rm cuda-repo-ubuntu2204-12-1-local_12.1.0-530.30.02-1_amd64.deb
    echo 'export CUDA_HOME=/usr/local/cuda-12.1' >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda-12.1/bin${PATH:+:${PATH}}' >> ~/.bashrc
}

function install_cuda_12_4() {
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get -y install cuda
    sudo apt-get -y install cuda-toolkit-12-4
    echo 'export CUDA_HOME=/usr/local/cuda-12.4' >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda-12.4/bin${PATH:+:${PATH}}' >> ~/.bashrc
}

function install_cuda_12_4_v2() {
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2204-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-12-4
    echo 'export PATH=/usr/local/cuda-12.4/bin${PATH:+:${PATH}}' >> ~/.bashrc
    PATH=/usr/local/cuda-12.4/bin${PATH:+:${PATH}}
}

function energy_tool(){
    sudo apt -y install likwid
    sudo modprobe msr
    sudo chmod a+rw /dev/cpu/*/msr
    pip install pynvml pandas scikit-learn
}

# base software
sudo apt-get update
sudo apt-get install -y git htop curl build-essential apt-transport-https ca-certificates gnupg lsb-release firewalld
git config --global pull.rebase false
sudo apt-get autoremove -y
sudo apt install at
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y mailutils postfix

# cuda 12.1
# nvidia-smi_status=$(nvidia-smi 2>&1)
# nvidia-smi 2>&1
# if [ $? -ne 0 ]; then
if ! command -v nvidia-smi &> /dev/null; then
    install_cuda_12_4
fi

# conda
MINICONDA_VERSION="latest"
INSTALLER_NAME="Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh"
INSTALLER_URL="https://repo.anaconda.com/miniconda/$INSTALLER_NAME"
wget -q $INSTALLER_URL
chmod +x $INSTALLER_NAME
sudo bash $INSTALLER_NAME -b -p /opt/miniconda
rm $INSTALLER_NAME
echo 'export PATH="/opt/miniconda/bin:$PATH"' >> "$HOME/.bashrc"
sudo chmod a+rw -R /opt/miniconda

# to install cuda
sudo reboot
