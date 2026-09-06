# CKS: kubeadm

[Back](../README.md)

- [CKS: kubeadm](#cks-kubeadm)
  - [setup controlplane with kubeadm](#setup-controlplane-with-kubeadm)
  - [setup worker node with kubeadm](#setup-worker-node-with-kubeadm)

---

## setup controlplane with kubeadm

- ref:
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

```sh
# ##############################
# configure system
# ##############################
# config system
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# apply system config
sudo sysctl --system

# ##############################
# Disable Swap
# ##############################
sudo swapoff -a
sudo sed -i '/swap/ s/^/#/' /etc/fstab

# ##############################
# install containerd
# ##############################
# configure module for containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# apply module config
sudo modprobe overlay
sudo modprobe br_netfilter

sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo vim /etc/containerd/config.toml
# SystemdCgroup = true

sudo systemctl restart containerd
sudo systemctl status containerd


# ##############################
# install kubeadm
# ##############################
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download the public signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# Add the appropriate Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

# ##############################
# Initializing control-plane node
# ##############################
ip a
# 172.27.224.217

sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.37.0

# ##############################
# Configure kubeconfig
# ##############################
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# ##############################
# Install Network Addon
# ##############################
# Remove the Taint:
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# node/ubuntu-node untainted

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml

# ##############################
# Verification
# ##############################
kubectl get nodes
# NAME          STATUS   ROLES           AGE     VERSION
# ubuntu-node   Ready    control-plane   6m18s   v1.37.0

kubectl run nginx --image=nginx
# pod/nginx created

kubectl get pods
# NAME    READY   STATUS    RESTARTS   AGE
# nginx   1/1     Running   0          15s
```

---

## setup worker node with kubeadm

```sh
# ##############################
# configure system
# ##############################
# config system
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# apply system config
sudo sysctl --system

# ##############################
# Disable Swap
# ##############################
sudo swapoff -a
sudo sed -i '/swap/ s/^/#/' /etc/fstab

# ##############################
# install containerd
# ##############################
# configure module for containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# apply module config
sudo modprobe overlay
sudo modprobe br_netfilter

sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

sudo vim /etc/containerd/config.toml
# SystemdCgroup = true

sudo systemctl restart containerd
sudo systemctl status containerd


# ##############################
# install kubeadm
# ##############################
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download the public signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# Add the appropriate Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

# join
sudo kubeadm join 10.0.0.167:6443 --token w04s1c.qg2m49492i6zpvjt --discovery-token-ca-cert-hash sha256:55f3da9ace263809270f91e0
```

- confirm

```sh
# controlplane
kubectl get node
# NAME            STATUS   ROLES           AGE   VERSION
# ubuntu-node     Ready    control-plane   32m   v1.37.0
# worker-node01   Ready    <none>          82s   v1.37.0
```

---
