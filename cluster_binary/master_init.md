# CKS - Master node: init

[Back](../../index.md)

- [CKS - Master node: init](#cks---master-node-init)
  - [VMs](#vms)
    - [Spec](#spec)
    - [Network](#network)
    - [Step](#step)
    - [Version](#version)
  - [Init](#init)

---

## VMs

### Spec

- Virtual Network
  - VMnet2
  - Type: NAT
  - DHCP: enabled
  - Subnet: 192.168.10.0/24
  - Gateway: 192.168.10.2

- Master Node:
  - Hostname: controlplane
  - OS: Ubuntu 24.04 LTS
  - CPU: 4 vCPU
  - Memory: 4 GB
  - Disk: 40 GB
  - IP: 192.168.10.180

- Worker Node 1:
  - Hostname: node01
  - OS: Ubuntu 24.04 LTS
  - CPU: 2 vCPU
  - Memory: 2 GB
  - Disk: 40 GB
  - IP: 192.168.10.181

- Worker Node 2:
  - Hostname: node02
  - OS: Ubuntu 24.04 LTS
  - CPU: 2 vCPU
  - Memory: 2 GB
  - Disk: 40 GB
  - IP: 192.168.10.182

---

### Network

Network ranges used below:

- Pod CIDR: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Cluster DNS: `10.96.0.10`
- apiserver ClusterIP: `10.96.0.1`

---

### Step

| #   | Layer         | Component                         |
| --- | ------------- | --------------------------------- |
| 0   | OS            | swap off, kernel modules, sysctl  |
| 1   | Runtime       | `containerd` and `runc`           |
| 2   | Trust         | CA + all certificates             |
| 3   | Trust         | kubeconfig files                  |
| 4   | State         | `etcd`                            |
| 5   | Control plane | `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` |
| 6   | Node          | `kubelet`, `kube-proxy`           |
| 7   | Network       | CNI plugin                        |
| 8   | Addon         | CoreDNS                           |

### Version

```sh
export K8S_VERSION=v1.35.8
export ETCD_VERSION=v3.6.14
```

---

## Init

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
# update & upgrade
# ##############################
sudo apt-get update
sudo apt-get upgrade -y


# ##############################
# Networking
# ##############################
# set hostname
sudo hostnamectl set-hostname controlplane

# set hosts
cat <<'EOF' | sudo tee -a /etc/hosts
192.168.10.180 controlplane
192.168.10.181 node01
192.168.10.182 node02
EOF

# set ip
cat <<'EOF' | sudo tee /etc/netplan/00-k8s.yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.10.180/24]
      routes:
        - to: default
          via: 192.168.10.2
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

sudo chmod 600 /etc/netplan/00-k8s.yaml
sudo netplan apply

# confirm
ip -br a
# lo               UNKNOWN        127.0.0.1/8 ::1/128
# ens33            UP             192.168.10.180/24

# ##############################
# Disable swap
# ##############################
sudo swapoff -a
sudo sed -i '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab

# confirm
grep swap /etc/fstab
#/swap.img      none    swap    sw      0       0

free -h
#                total        used        free      shared  buff/cache   available
# Mem:           3.8Gi       1.1Gi       1.7Gi        32Mi       1.2Gi       2.6Gi
# Swap:             0B          0B          0B

# ##############################
# Kernel modules
# ##############################
# overlay: the union filesystem containerd uses for image layers.
# br_netfilter: lets iptables see traffic crossing a Linux bridge, which is how `kube-proxy` Service rules reach pod traffic.
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
# overlay
# br_netfilter

# load kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# confirm
lsmod | grep -E 'overlay|br_netfilter'
# br_netfilter           32768  0
# bridge                421888  1 br_netfilter
# overlay               221184  0

# kernel parameters: network
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# kernel parameters: kubelet
cat <<'EOF' | sudo tee /etc/sysctl.d/90-kubelet.conf
vm.overcommit_memory        = 1
vm.panic_on_oom             = 0
kernel.panic                = 10
kernel.panic_on_oops        = 1
kernel.keys.root_maxkeys    = 1000000
kernel.keys.root_maxbytes   = 25000000
EOF

# applies all system kernel configuration
sudo sysctl --system

# confirm
sudo sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
# net.ipv4.ip_forward = 1
# net.bridge.bridge-nf-call-iptables = 1

sudo sysctl vm.overcommit_memory vm.panic_on_oom kernel.panic kernel.panic_on_oops
# vm.overcommit_memory = 1
# vm.panic_on_oom = 0
# kernel.panic = 10
# kernel.panic_on_oops = 1

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
