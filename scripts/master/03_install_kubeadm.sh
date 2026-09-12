#!/bin/bash
# A shell script to install kubeadm.
# Permission as sudo
# sudo bash 03_install_kubeadm.sh

K8S_VERSION="v1.33"

# ##############################
# Install support packages
# ##############################
echo 
echo "########## Install packages ##########"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

# ##############################
# Configure Kubernetes apt repo
# ##############################
echo 
echo "/n########## Configure Kubernetes apt repo ##########/n"
mkdir -pv /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# ##############################
# Install kubelet kubeadm kubectl
# ##############################
echo 
echo "/n########## Install kubelet kubeadm kubectl ##########/n"
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service
systemctl enable --now kubelet

# confirm client version
kubectl version --client
# Client Version: v1.31.14
# Kustomize Version: v5.4.2

# ##############################
# Configure crictl
# ##############################
echo 
echo "/n########## Configure crictl ##########/n"
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# confirm
crictl ps
