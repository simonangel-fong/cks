# CKS setup: initialize the worker node

```sh

HOSTNAME="node01"
IP_HOST="192.168.10.151"
IP_GTW="192.168.10.2"
INTERFACE="ens33"

# ##############################
# Set hostname
# ##############################
sudo hostnamectl set-hostname "$HOSTNAME"
hostnamectl hostname
# node01

# ########## Update hosts ##########
sudo tee -a /etc/hosts <<EOF
$IP_HOST   $HOSTNAME
EOF
# 192.168.10.151   node01

# ##############################
# Configure a static IP with Netplan
# ##############################
# Identify the network interface.
ip -br link
# lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
# ens33            UP             00:0c:29:a5:35:de <BROADCAST,MULTICAST,UP,LOWER_UP>

# Configure the static address, default route, and DNS servers.
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
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

sudo chmod -v 600 /etc/netplan/01-netcfg.yaml
# mode of '/etc/netplan/01-netcfg.yaml' changed from 0644 (rw-r--r--) to 0600 (rw-------)
sudo netplan generate
sudo netplan apply

# ########## Verify networking ##########
ip -br address
# lo               UNKNOWN        127.0.0.1/8 ::1/128
# ens33            UP             192.168.10.151/24 192.168.10.140/24 fe80::20c:29ff:fea5:35de/64
ip route
# default via 192.168.10.2 dev ens33 proto static metric 100
# default via 192.168.10.2 dev ens33 proto dhcp src 192.168.10.140 metric 100
# 192.168.10.0/24 dev ens33 proto kernel scope link src 192.168.10.151 metric 100
# 192.168.10.0/24 dev ens33 proto kernel scope link src 192.168.10.140 metric 100
ping -c 3 google.com
# PING google.com (142.250.137.100) 56(84) bytes of data.
# 64 bytes from pnyyzb-in-f100.1e100.net (142.250.137.100): icmp_seq=1 ttl=128 time=17.4 ms
# 64 bytes from pnyyzb-in-f100.1e100.net (142.250.137.100): icmp_seq=2 ttl=128 time=20.1 ms
# 64 bytes from pnyyzb-in-f100.1e100.net (142.250.137.100): icmp_seq=3 ttl=128 time=18.1 ms

# --- google.com ping statistics ---
# 3 packets transmitted, 3 received, 0% packet loss, time 2003ms
# rtt min/avg/max/mdev = 17.415/18.543/20.143/1.162 ms

# ##############################
# Update packages and install basic tools
# ##############################
sudo apt update && sudo apt upgrade -y
sudo apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable swap
# ##############################
sudo swapoff -av
# swapoff /swap.img
sudo sed -i '/swap/ s/^/#/' /etc/fstab

# ########## Verify swap is disabled ##########
sudo free -h
#                total        used        free      shared  buff/cache   available
# Mem:           1.9Gi       1.1Gi        84Mi        29Mi       935Mi       807Mi
# Swap:             0B          0B          0B

# ##############################
# Reboot
# ##############################
sudo reboot

```
