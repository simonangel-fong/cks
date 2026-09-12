#!/bin/bash
# A shell script to initialize a VM for k8s worker node.
# Permission as sudo
# sudo bash 01_init_node01.sh

HOSTNAME="node01"
IP_HOST="192.168.10.151"
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
# Identify the network interface.
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
