# CKS setup: master init

```sh
HOSTNAME="controlplane"
IP_HOST="192.168.10.150"
IP_GTW="192.168.10.2"

# ##############################
# set hostname
# ##############################
sudo hostnamectl set-hostname $HOSTNAME
hostnamectl hostname

# ########## add hosts ##########
sudo tee -a /etc/hosts <<EOF
$IP_HOST   controlplane
127.0.0.1        localhost
EOF


# ##############################
# Netplan Static IP Configuration
# ##############################
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
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

sudo chmod -v 600 /etc/netplan/*
sudo netplan apply

# ########## confirm ##########
ip a
ping -c 3 google.com

# ##############################
# Update Packages + Install Basic Tools
# ##############################
sudo apt update && apt upgrade -y
sudo apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable Swap
# ##############################
sudo swapoff -av
sudo sed -i '/swap/ s/^/#/' /etc/fstab

# ########## confirm ##########
sudo free -h

# ##############################
# Reboot
# ##############################
# sudo reboot
sudo shutdown now

```
