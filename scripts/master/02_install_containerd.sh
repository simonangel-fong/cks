#!/bin/bash
# Install and configure containerd for the control plane node.
# Permission as sudo
# sudo bash 02_install_containerd.sh

# Enable IPv4 forwarding.
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# ##############################
# Install containerd
# ##############################
sudo apt-get update
sudo apt-get install -y containerd

# ##############################
# Configure containerd
# ##############################
# Generate default config
sudo mkdir -pv /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Use the systemd cgroup driver.
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Apply the configuration.
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd --no-page
