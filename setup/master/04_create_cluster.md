# CKS setup: master create cluster

```sh
IP_CONTROLPLANE="192.168.10.150"
IP_POD_CIDR="10.244.0.0/16"

# ##############################
# Kernel modules for Kubernetes networking
# ##############################
# config module
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ##############################
# Enable IP forwarding & bridge settings
# ##############################
# config systctl
tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# apply all sysctl configs
sysctl --system

# confirm
sysctl net.ipv4.ip_forward

# ##############################
# Initialize control plane
# ##############################
kubeadm init --apiserver-advertise-address=$IP_CONTROLPLANE --pod-network-cidr=$IP_POD_CIDR --cri-socket=unix:///var/run/containerd/containerd.sock

# ##############################
# Configure kubectl for current user
# ##############################
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# confirm
kubectl get nodes

# ##############################
# Join command
# ##############################
sudo kubeadm token create --print-join-command
```