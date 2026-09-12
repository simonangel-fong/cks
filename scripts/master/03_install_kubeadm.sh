#!/bin/bash
# A shell script to install kubeadm.
# Permission as sudo
# sudo bash 03_install_kubeadm.sh

K8S_VERSION="v1.35"

# ##############################
# Install support packages
# ##############################
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

# ##############################
# Configure Kubernetes apt repo
# ##############################
mkdir -pv /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# ##############################
# Install kubelet kubeadm kubectl
# ##############################
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service
systemctl enable --now kubelet

# Verify the client version
kubectl version --client

# ##############################
# Install and configure crictl
# ##############################
apt-get install -y cri-tools
apt-mark hold cri-tools

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Verify runtime connectivity
crictl ps
