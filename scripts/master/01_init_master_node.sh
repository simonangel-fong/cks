#!/bin/bash
# A shell script to initialize a VM for k8s controlplane.
# Permission as sudo
# sudo 01_init_master_node.sh

HOSTNAME="controlplane"
IP_HOST="192.168.10.150"
IP_GTW="192.168.10.2"

# ##############################
# set hostname
# ##############################
hostnamectl set-hostname $HOSTNAME
hostnamectl hostname

# ########## add hosts ##########
tee -a /etc/hosts <<EOF
$IP_HOST   controlplane
127.0.0.1        localhost
EOF


# ##############################
# Netplan Static IP Configuration
# ##############################
tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      addresses:
        - $IP_HOST/24
      routes:
        - to: default
          via: $IP_GTW
      nameservers:
        addresses: [$IP_GTW, 8.8.8.8, 1.1.1.1]
EOF

chmod -v 600 /etc/netplan/*
netplan apply

# ########## confirm ##########
ip a
ping -c 3 google.com

# ##############################
# Update Packages + Install Basic Tools
# ##############################
apt update && apt upgrade -y
apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable Swap
# ##############################
swapoff -av
sed -i '/swap/ s/^/#/' /etc/fstab

# ########## confirm ##########
free -h

# # ##############################
# # Reboot
# # ##############################
# reboot