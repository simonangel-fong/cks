#!/bin/bash
# A shell script to initialize a VM for k8s worker node.
# Permission as sudo
# sudo 01_init_worker_node.sh

HOSTNAME="worker01"
IP_HOST="192.168.10.151"
IP_GTW="192.168.10.2"

# ##############################
# set hostname
# ##############################
echo "########## set hostname ##########"
hostnamectl set-hostname $HOSTNAME
hostnamectl hostname

# add hosts
echo "########## add hosts ##########"
tee -a /etc/hosts <<EOF
$IP_HOST   controlplane
127.0.0.1        localhost
EOF


# ##############################
# Netplan Static IP Configuration
# ##############################
echo "########## netplan ##########"
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
echo "########## Update packages ##########"
apt update && apt upgrade -y
apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable Swap
# ##############################
echo "########## disable swap ##########"
swapoff -av
sed -i '/swap/ s/^/#/' /etc/fstab

# confirm
free -h

# ##############################
# Reboot
# ##############################
echo "########## reboot ##########"
reboot