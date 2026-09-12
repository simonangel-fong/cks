#!/bin/bash
# Initialize a VM as a Kubernetes control plane node.
# Run with: sudo bash scripts/master/01_init_master_node.sh

HOSTNAME="controlplane"
IP_HOST="192.168.10.150"
IP_GTW="192.168.10.2"
INTERFACE="ens33"

# ##############################
# Set hostname
# ##############################
hostnamectl set-hostname "$HOSTNAME"
hostnamectl hostname

# ########## Update hosts ##########
tee -a /etc/hosts <<EOF
$IP_HOST   $HOSTNAME
EOF

# ##############################
# Configure a static IP with Netplan
# ##############################
# get network interface.
ip -br link

# Configure the static address, default route, and DNS servers.
tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $IP_HOST/24
      routes:
        - to: default
          via: $IP_GTW
      nameservers:
        addresses: [$IP_GTW, 8.8.8.8, 1.1.1.1]
EOF

chmod -v 600 /etc/netplan/01-netcfg.yaml
netplan generate
netplan apply

# ########## Verify networking ##########
ip -br address
ip route
ping -c 3 google.com

# ##############################
# Update packages and install basic tools
# ##############################
apt update && apt upgrade -y
apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable swap
# ##############################
swapoff -av
sed -i '/swap/ s/^/#/' /etc/fstab

# ########## Verify swap is disabled ##########
free -h

# ##############################
# Reboot
# ##############################
reboot
