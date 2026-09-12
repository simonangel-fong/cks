#!/bin/bash
# Create the Kubernetes control plane.
# Run as your regular user: bash 04_create_cluster.sh

IP_CONTROLPLANE="192.168.10.150"
IP_POD_CIDR="10.244.0.0/16"

# ##############################
# Kernel modules for Kubernetes networking
# ##############################
# Load networking modules at boot.
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# ##############################
# Enable IP forwarding & bridge settings
# ##############################
# Configure sysctl settings.
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# Apply sysctl settings.
sudo sysctl --system

# Verify IPv4 forwarding.
sysctl net.ipv4.ip_forward

# ##############################
# Initialize control plane
# ##############################
sudo kubeadm init --apiserver-advertise-address="$IP_CONTROLPLANE" --pod-network-cidr="$IP_POD_CIDR" --cri-socket=unix:///var/run/containerd/containerd.sock

# ##############################
# Configure kubectl for current user
# ##############################
# Sleep for 120 seconds
sleep 120
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Verify node registration (NotReady until CNI installation).
kubectl get nodes

# ##############################
# Join command
# ##############################
sudo kubeadm token create --print-join-command
