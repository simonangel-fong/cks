# CKS - Worker node: init

[Back](../../index.md)

- [CKS - Worker node: init](#cks---worker-node-init)
  - [VM](#vm)
    - [Specification](#specification)
    - [Network](#network)
    - [Steps](#steps)
    - [Version](#version)
  - [Initialize worker](#initialize-worker)

---

## VM

### Specification

- Virtual network: VMnet2
- Network type: NAT
- Subnet: 192.168.10.0/24
- Gateway: 192.168.10.2
- Hostname: node01
- OS: Ubuntu 24.04 LTS
- CPU: 2 vCPU
- Memory: 2 GB
- Disk: 40 GB
- IP: 192.168.10.181

### Network

- Pod CIDR: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Cluster DNS: `10.96.0.10`
- API server: `192.168.10.180:6443`

### Steps

| #   | Layer      | Component                         |
| --- | ---------- | --------------------------------- |
| 0   | OS         | Swap, kernel modules and sysctl   |
| 1   | Runtime    | `containerd`, `runc` and `crictl` |
| 2   | Connection | Certificates and kubeconfigs      |
| 3   | Node       | `kubelet`                         |
| 4   | Network    | `kube-proxy`                      |
| 5   | Validation | Node, CNI, Service and DNS tests  |

### Version

```sh
export K8S_VERSION=v1.35.8
```

---

## Initialize worker

| Sysctl                      | Expected   |
| --------------------------- | ---------- |
| `vm.overcommit_memory`      | `1`        |
| `vm.panic_on_oom`           | `0`        |
| `kernel.panic`              | `10`       |
| `kernel.panic_on_oops`      | `1`        |
| `kernel.keys.root_maxkeys`  | `1000000`  |
| `kernel.keys.root_maxbytes` | `25000000` |

```sh
# ##############################
# Update packages
# ##############################
sudo apt-get update
sudo apt-get upgrade -y

# ##############################
# Configure networking
# ##############################
sudo hostnamectl set-hostname node01

cat <<'EOF' | sudo tee -a /etc/hosts
192.168.10.180 controlplane
192.168.10.181 node01
192.168.10.182 node02
EOF

cat <<'EOF' | sudo tee /etc/netplan/00-k8s.yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: false
      addresses: [192.168.10.181/24]
      routes:
        - to: default
          via: 192.168.10.2
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

sudo chmod 600 /etc/netplan/00-k8s.yaml
sudo netplan apply

hostname
# node01

ip -br address show ens33
# ens33            UP             192.168.10.181/24 10.0.0.219/24 2607:fea8:2adc:8500:d24a:18d1:cf06:c6c2/64 2607:fea8:2adc:8500:20c:29ff:fe3b:d8a7/64 fe80::20c:29ff:fe3b:d8a7/64

# ##############################
# Disable swap
# ##############################
sudo swapoff -a
sudo sed -i '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab

free -h
#                total        used        free      shared  buff/cache   available
# Mem:           7.7Gi       834Mi       6.4Gi        13Mi       713Mi       6.9Gi
# Swap:             0B          0B          0B

# ##############################
# Load kernel modules
# ##############################
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

lsmod | grep -E 'overlay|br_netfilter'
# br_netfilter           32768  0
# bridge                421888  1 br_netfilter
# overlay               212992  0

# ##############################
# Configure kernel parameters
# ##############################
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

cat <<'EOF' | sudo tee /etc/sysctl.d/90-kubelet.conf
vm.overcommit_memory        = 1
vm.panic_on_oom             = 0
kernel.panic                = 10
kernel.panic_on_oops        = 1
kernel.keys.root_maxkeys    = 1000000
kernel.keys.root_maxbytes   = 25000000
EOF

sudo sysctl --system

sudo sysctl \
  net.ipv4.ip_forward \
  net.bridge.bridge-nf-call-iptables \
  vm.overcommit_memory \
  vm.panic_on_oom \
  kernel.panic \
  kernel.panic_on_oops \
  kernel.keys.root_maxkeys \
  kernel.keys.root_maxbytes

# ##############################
# Disable firewall for the lab
# ##############################
sudo systemctl disable --now ufw 2>/dev/null || true

# ##############################
# Install tools
# ##############################
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# ##############################
# Reboot
# ##############################
sudo reboot
```

---
