# CKS setup: initialize the master node

```sh
HOSTNAME="controlplane"
IP_HOST="192.168.10.150"
IP_GTW="192.168.10.2"
INTERFACE="ens33"

# ##############################
# Set hostname
# ##############################
sudo hostnamectl set-hostname "$HOSTNAME"
hostnamectl hostname
# controlplane

# ########## Update hosts ##########
sudo tee -a /etc/hosts <<EOF
$IP_HOST   $HOSTNAME
EOF
# 192.168.10.150   controlplane

# ##############################
# Configure a static IP with Netplan
# ##############################
# get network interface.
ip -br link
# lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
# ens33            UP             00:0c:29:cb:93:9a <BROADCAST,MULTICAST,UP,LOWER_UP>

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
# ens33            UP             192.168.10.150/24 192.168.10.139/24 fe80::20c:29ff:fecb:939a/64
ip route
# default via 192.168.10.2 dev ens33 proto static metric 100
# default via 192.168.10.2 dev ens33 proto dhcp src 192.168.10.139 metric 100
# 192.168.10.0/24 dev ens33 proto kernel scope link src 192.168.10.150 metric 100
# 192.168.10.0/24 dev ens33 proto kernel scope link src 192.168.10.139 metric 100
ping -c 3 google.com
# PING google.com (142.250.137.138) 56(84) bytes of data.
# 64 bytes from pnyyzb-in-f138.1e100.net (142.250.137.138): icmp_seq=1 ttl=128 time=18.4 ms
# 64 bytes from pnyyzb-in-f138.1e100.net (142.250.137.138): icmp_seq=2 ttl=128 time=20.1 ms
# 64 bytes from pnyyzb-in-f138.1e100.net (142.250.137.138): icmp_seq=3 ttl=128 time=20.5 ms

# --- google.com ping statistics ---
# 3 packets transmitted, 3 received, 0% packet loss, time 2003ms
# rtt min/avg/max/mdev = 18.424/19.687/20.529/0.909 ms

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
ubuntuadmin@ubuntu-node:~$ sudo free -h
#                total        used        free      shared  buff/cache   available
# Mem:           3.8Gi       1.3Gi       523Mi        29Mi       2.3Gi       2.5Gi
# Swap:             0B          0B          0B

# ##############################
# Reboot
# ##############################
sudo reboot

```
