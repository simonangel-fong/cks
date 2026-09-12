#!/bin/bash
# A shell script to install containerd.
# Permission as sudo
# sudo 02_install_containerd.sh

# ##############################
# Install containerd
# ##############################
echo "########## Install containerd ###########"
apt-get update
apt-get install -y containerd

# ##############################
# Configure containerd
# ##############################
echo "########## Configure containerd ##########"
# Generate default config
mkdir -pv /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Set systemd cgroup driver: Sets SystemdCgroup = true
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# apply the change
systemctl restart containerd
systemctl enable --now containerd
systemctl status containerd --no-page