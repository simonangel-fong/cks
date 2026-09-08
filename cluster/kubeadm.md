# CKS: Install & update cluster with kubeadm

[Back](../README.md)

- [CKS: Install \& update cluster with kubeadm](#cks-install--update-cluster-with-kubeadm)
  - [Version Skew Policy](#version-skew-policy)
    - [Kubernetes Versioning](#kubernetes-versioning)
    - [Components](#components)
  - [kubeadm](#kubeadm)
  - [File structure](#file-structure)
    - [Control plane](#control-plane)
    - [Worker node](#worker-node)
  - [Lab: setup controlplane with kubeadm](#lab-setup-controlplane-with-kubeadm)
  - [lab: setup worker node with kubeadm](#lab-setup-worker-node-with-kubeadm)
  - [troubleshooting](#troubleshooting)
  - [Upgrading kubeadm Clusters](#upgrading-kubeadm-clusters)
    - [Control Plane](#control-plane-1)

---

## Version Skew Policy

- `version skew`
  - the **difference in version** numbers **between different components** running inside the **same cluster**.
  - Because Kubernetes is a **distributed system** with many moving parts (like the API server, nodes, and CLI tools), it is designed to let these parts r**un on different versions** temporarily—usually during rolling upgrades.

- `version skew policy`
  - the **maximum allowable difference** in **minor versions (1.X.z)** between various cluster components.

---

### Kubernetes Versioning

- `Kubernetes versions` are expressed as `x.y.z`
  - `x`: the major version
  - `y`: the minor version
  - `z`: the patch version

- Format: `<MAJOR>.<MINOR>.<PATCH>`
  - e.g., v1.32.2

| Major Version | Minor Version | Patch Version |
| ------------- | ------------- | ------------- |
| 1             | 32            | 2             |

---

### Components

- `kube-apiserver`
  - In highly-available (HA) clusters, the newest and oldest kube-apiserver instances must be **within one minor version**.
    - e.g., If newest kube-apiserver is at 1.32 other kube-apiserver instances are supported at 1.32 and 1.31

- `kubelet`
  - `kubelet` must **not be newer** than `kube-apiserver`.
  - `kubelet` may be up to **three minor versions older** than `kube-apiserver`
  - e.g.,
    - `kube-apiserver` is at 1.32
    - `kubelet` is supported at 1.32, 1.31, 1.30, and 1.29

- `kube-proxy`
  - `kube-proxy` must **not be newer** than `kube-apiserver`.
  - `kube-proxy` may be up to **three minor versions older** than `kube-apiserver`
  - e.g.,
    - `kube-apiserver` is at 1.32
    - `kube-proxy` is supported at 1.32, 1.31, 1.30, and 1.29

- `Controller Manager`, `Scheduler`, `Cloud Controller Manager`
  - Must **not be newer** than the `kube-apiserver` instances they communicate with.
  - They are **expected to match** the `kube-apiserver` minor version, but may be up to **one minor version older** (to allow live upgrades).
  - e.g.,
    - `kube-apiserver` is at 1.32
    - `kube-controller-manager`, `kube-scheduler`, and `cloud-controller-manager` are supported at 1.32 and 1.31

- `kubectl`
  - `kubectl` is supported within **one minor version (older or newer)** of `kube-apiserver`.
  - e.g.,
    - kube-apiserver is at 1.32
    - kubectl is supported at 1.33, 1.32, and 1.31

---

## kubeadm

- ref:
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
  - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

---

## File structure

### Control plane

```text
/etc/kubernetes/                    # Typical control plane + local etcd
|-- admin.conf                     # Admin kubeconfig
|-- super-admin.conf               # Break-glass kubeconfig (init node)
|-- controller-manager.conf        # Controller manager kubeconfig
|-- scheduler.conf                 # Scheduler kubeconfig
|-- kubelet.conf                   # Kubelet kubeconfig
|-- bootstrap-kubelet.conf         # Temporary; removed after bootstrap
|-- manifests/                     # Static Pods (watched by kubelet)
|   |-- kube-apiserver.yaml        # API server
|   |-- kube-controller-manager.yaml
|   |-- kube-scheduler.yaml
|   `-- etcd.yaml                  # Local etcd
|-- pki/                           # .crt = certificate; .key = private key
|   |-- ca.crt                     # Kubernetes CA
|   |-- ca.key
|   |-- apiserver.crt              # API server TLS
|   |-- apiserver.key
|   |-- apiserver-kubelet-client.crt # API server -> kubelet
|   |-- apiserver-kubelet-client.key
|   |-- apiserver-etcd-client.crt   # API server -> etcd
|   |-- apiserver-etcd-client.key
|   |-- front-proxy-ca.crt         # API aggregation CA
|   |-- front-proxy-ca.key
|   |-- front-proxy-client.crt     # API aggregation client
|   |-- front-proxy-client.key
|   |-- sa.key                     # ServiceAccount token signing
|   |-- sa.pub                     # ServiceAccount token verification
|   `-- etcd/
|       |-- ca.crt                 # etcd CA
|       |-- ca.key
|       |-- server.crt             # etcd server TLS
|       |-- server.key
|       |-- peer.crt               # etcd <-> etcd mTLS
|       |-- peer.key
|       |-- healthcheck-client.crt # etcd health-check client
|       `-- healthcheck-client.key
`-- tmp/                           # Temporary / upgrade files (if present)
```

key files:

- `/etc/kubernetes/admin.conf`: admin kubeconfig, a copy in ~/.kube/config
- `/etc/kubernetes/kubelet.conf`: contain cert with
  - CN: `system:node:<hostname-lowercased>`
  - O: `system:node`
- `/etc/kubernetes/controller-manager.conf`: contains a cert with
  - CN: `system:kube-controller-manager`
- `/etc/kubernetes/scheduler.conf`: contains a cert with
  - CN: `system:kube-scheduler`

**IMPORTANT**:

- `kubelet` is manage by systemd
  - path: `/var/lib/kubelet/`
  - key file: `/var/lib/kubelet/config.yaml`
- component static pods all get labels:
  - `tier:control-plane`
  - `component:<component_name>`
    - e.g., `component:etcd`

- control plane node automaticall has
  - labels: `node-role.kubernetes.io/control-plane=`
  - tains: `node-role.kubernetes.io/control-plane:NoSchedule`

---

### Worker node

```text
/etc/kubernetes/                    # Typical kubeadm worker
|-- kubelet.conf                   # Kubelet -> API server kubeconfig
|-- bootstrap-kubelet.conf         # Temporary; removed after bootstrap
|-- manifests/                     # Empty by default; custom static Pods
`-- pki/
    `-- ca.crt                     # Kubernetes CA certificate
```

---

## Lab: setup controlplane with kubeadm

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

## lab: setup worker node with kubeadm

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

## troubleshooting

kubelet logs

```sh
# kubelet log
journalctl -u kubelet -f

# pod log
sudo ls /var/log/pods
# container log: symlink to the latest log file for Pods
sudo ls /var/log/containers

sudo grep -i "error" log_file
```

---

## Upgrading kubeadm Clusters

- upgrade minor versions sequentially (1.31 -> 1.32 -> 1.33 etc.)
- upgrade both the Control Plane Node and Worker Nodes.

```sh
# queries and displays available information about installed and installable packages.
apt-cache madison kubeadm
```

---

### Control Plane

- `kubeadm upgrade plan` check which versions are available to upgrade to and validate whether your current cluster is upgradeable
- Run the `kubeadm upgrade apply` to upgrade the version.

- `kubelet` component: not upgraded during the `kubeadm upgrade apply` operation.
  - have to manually upgrade `kubelet`.
