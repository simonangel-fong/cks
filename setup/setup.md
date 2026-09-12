# Setup env

[Back](../README.md)

- [Setup env](#setup-env)
  - [Steps](#steps)
  - [Create VM](#create-vm)
  - [Setup Controlplane](#setup-controlplane)
    - [Configure VM](#configure-vm)
    - [Install `containerd`](#install-containerd)
    - [Install `kubeadm`](#install-kubeadm)
    - [Create Cluster with `kubeadm`](#create-cluster-with-kubeadm)
    - [Join Worker Nodes](#join-worker-nodes)
    - [Install CNI - `Calico`](#install-cni---calico)
    - [Install CSI - `rancher`](#install-csi---rancher)
    - [Install Metrics Server](#install-metrics-server)
    - [Install `etcd-client`](#install-etcd-client)
    - [Install `helm`](#install-helm)
    - [Install `nginx ingress controller`](#install-nginx-ingress-controller)
    - [Install `Nginx Gateway Fabric`](#install-nginx-gateway-fabric)
    - [Install VPA](#install-vpa)
    - [Install `MetalLB`](#install-metallb)

---

## Steps

- Create VMs
- Init: setup ip
- Install containered
- Install kubeadm
- Create control plane
- install pod network
- Join all worker nodes to the master node

---

## Create VM

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
  - Disk: 40GB
  - IP: 192.168.10.150

- Worker Node 1:
  - Hostname: node01
  - OS: Ubuntu 24.04 LTS
  - CPU: 2 vCPU
  - Memory: 2 GB
  - Disk: 40GB
  - IP: 192.168.10.151

- Worker Node 2:
  - Hostname: node02
  - OS: Ubuntu 24.04 LTS
  - CPU: 2 vCPU
  - Memory: 2 GB
  - Disk: 40GB
  - IP: 192.168.10.152

---

## Setup Controlplane

### Configure VM

```sh
# ##############################
# set hostname
# ##############################
sudo hostnamectl set-hostname controlplane

# add hosts
sudo tee -a /etc/hosts <<EOF
192.168.10.150   controlplane
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
        - 192.168.10.150/24
      routes:
        - to: default
          via: 192.168.10.2
      nameservers:
        addresses: [192.168.10.2, 8.8.8.8, 1.1.1.1]
EOF

sudo chmod 600 /etc/netplan/*
sudo netplan apply

# confirm
ip a
ping -c 3 google.com

# ##############################
# Update Packages + Install Basic Tools
# ##############################
sudo apt update && sudo apt upgrade -y
sudo apt install -y vim git curl ca-certificates net-tools traceroute tcpdump htop

# ##############################
# Disable Swap
# ##############################
sudo swapoff -a
sudo sed -i '/swap/ s/^/#/' /etc/fstab

# confirm
free -h

# ##############################
# Reboot
# ##############################
sudo reboot
```

---

### Install `containerd`

```sh
# ##############################
# Install containerd
# ##############################
sudo apt-get update
sudo apt-get install -y containerd

# ##############################
# Configure containerd
# ##############################
# Generate default config
sudo mkdir -pv /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Set systemd cgroup driver: Sets SystemdCgroup = true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# apply the change
sudo systemctl restart containerd
sudo systemctl enable --now containerd
# sudo systemctl status containerd
```

---

### Install `kubeadm`

```sh
# ##############################
# Install support packages
# ##############################
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# ##############################
# Configure Kubernetes apt repo
# ##############################
sudo mkdir -pv /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# ##############################
# Install kubelet kubeadm kubectl
# ##############################
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service
sudo systemctl enable --now kubelet

# confirm client version
kubectl version --client
# Client Version: v1.31.14
# Kustomize Version: v5.4.2

cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# confirm
sudo crictl ps
```

---

### Create Cluster with `kubeadm`

```sh
# ##############################
# Kernel modules for Kubernetes networking
# ##############################
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# ##############################
# Enable IP forwarding & bridge settings
# ##############################
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# apply all sysctl configs
sudo sysctl --system

# confirm
sysctl net.ipv4.ip_forward
# expected: net.ipv4.ip_forward = 1

# ##############################
# Initialize control plane
# ##############################
sudo kubeadm init --apiserver-advertise-address=192.168.10.150 --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

# ##############################
# Configure kubectl for current user
# ##############################
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# confirm
kubectl get nodes
```

---

### Join Worker Nodes

```sh
# ssh master
kubeadm token create --print-join-command
kubeadm join 192.168.10.150:6443 --token t66zr2.klkr2r --discovery-token-ca-cert-hash sha256:8e6f959b923206

# ssh worker node
sudo kubeadm join 192.168.10.150:6443 --token t66zr2.klkr2r --discovery-token-ca-cert-hash sha256:8e6f959b923206

# get node
kubectl get node
# NAME           STATUS     ROLES           AGE     VERSION
# controlplane   NotReady   control-plane   14m     v1.32.11
# node01         NotReady   <none>          3m34s   v1.32.11
# node02         NotReady   <none>          3m6s    v1.32.11
```

---

### Install CNI - `Calico`

```sh
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/operator-crds.yaml
# customresourcedefinition.apiextensions.k8s.io/apiservers.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/gatewayapis.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/goldmanes.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/imagesets.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/installations.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/managementclusterconnections.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/tigerastatuses.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/whiskers.operator.tigera.io created
# customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/stagedglobalnetworkpolicies.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/stagedkubernetesnetworkpolicies.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/stagednetworkpolicies.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/tiers.crd.projectcalico.org created
# customresourcedefinition.apiextensions.k8s.io/adminnetworkpolicies.policy.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/baselineadminnetworkpolicies.policy.networking.k8s.io created

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml
# namespace/tigera-operator created
# serviceaccount/tigera-operator created
# clusterrole.rbac.authorization.k8s.io/tigera-operator-secrets created
# clusterrole.rbac.authorization.k8s.io/tigera-operator created
# clusterrolebinding.rbac.authorization.k8s.io/tigera-operator created
# rolebinding.rbac.authorization.k8s.io/tigera-operator-secrets created
# deployment.apps/tigera-operator created

# get cluster ip cidr
kubectl cluster-info dump | grep -m 1 cluster-cidr
# "--cluster-cidr=10.244.0.0/16"

# Download the custom resources necessary to configure Calico.
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  1046  100  1046    0     0   3587      0 --:--:-- --:--:-- --:--:--  3594

# update the manifest with the cluster cidr
vi custom-resources.yaml
# find:
# spec:
#   calicoNetwork:
#     ipPools:
#       - name: default-ipv4-ippool
#         cidr: 192.168.0.0/16
# replace:
# spec:
#   calicoNetwork:
#     ipPools:
#       - name: default-ipv4-ippool
#         cidr: 10.244.0.0/16

# create resources
kubectl create -f custom-resources.yaml
# installation.operator.tigera.io/default created
# apiserver.operator.tigera.io/default created
# goldmane.operator.tigera.io/default created
# whisker.operator.tigera.io/default created

# wait until all available
watch kubectl get tigerastatus
# Every 2.0s: kubectl get tigerastatus                        controlplane: Sat Jan 17 00:23:23 2026

# NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
# apiserver   True        False         False      59s
# calico      True        False         False      9s
# goldmane    True        False         False      39s
# ippools     True        False         False      2m19s
# whisker     True        False         False      54s

# confirm: node status ready
kubectl get node
# NAME           STATUS   ROLES           AGE   VERSION
# controlplane   Ready    control-plane   23m   v1.32.11
# node01         Ready    <none>          21m   v1.32.11
# node02         Ready    <none>          20m   v1.32.11
```

---

### Install CSI - `rancher`

```sh
# install
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# namespace/local-path-storage created
# serviceaccount/local-path-provisioner-service-account created
# role.rbac.authorization.k8s.io/local-path-provisioner-role created
# clusterrole.rbac.authorization.k8s.io/local-path-provisioner-role created
# rolebinding.rbac.authorization.k8s.io/local-path-provisioner-bind created
# clusterrolebinding.rbac.authorization.k8s.io/local-path-provisioner-bind created
# deployment.apps/local-path-provisioner created
# storageclass.storage.k8s.io/local-path created
# configmap/local-path-config created

# confirm
kubectl get sc
# NAME         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# local-path   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  3m3s

# set default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# storageclass.storage.k8s.io/local-path patched

kubectl get sc
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  20m

```

---

### Install Metrics Server

- ref: https://kubernetes-sigs.github.io/metrics-server/

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# serviceaccount/metrics-server created
# clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
# clusterrole.rbac.authorization.k8s.io/system:metrics-server created
# rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
# clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
# clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
# service/metrics-server created
# deployment.apps/metrics-server created
# apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created

# confirm install
kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# metrics-server   0/1     1            0           6m8s

# update yaml metrics server
kubectl edit deployment metrics-server -n kube-system
# find:
# spec:
#   template:
#     spec:
#       containers:
#       - args:
# add:
# spec:
#   template:
#     spec:
#       containers:
#       - args:
#         - --kubelet-insecure-tls
#         - --kubelet-preferred-address-types=InternalIP

# restart metric server
kubectl rollout restart deployment metrics-server -n kube-system
# deployment.apps/metrics-server restarted

kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# metrics-server   1/1     1            1           9m13s

# confirm
kubectl top node
# NAME           CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
# controlplane   153m         3%       2266Mi          60%
# node01         29m          2%       941Mi           51%
# node02         38m          3%       866Mi           47%
```

---

### Install `etcd-client`

```sh
# install
sudo apt install etcd-client

# confirm
etcdctl version
# etcdctl version: 3.4.30
# API version: 3.4
```

---

### Install `helm`

```sh
sudo apt-get install curl gpg apt-transport-https --yes

# update key
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
# deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main

# install
sudo apt-get update
sudo apt-get install helm

# confirm
helm version
# version.BuildInfo{Version:"v3.19.3", GitCommit:"0707f566a3f4ced24009ef14d67fe0ce69db4be9", GitTreeState:"clean", GoVersion:"go1.24.10"}
```

---

### Install `nginx ingress controller`

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml
# namespace/ingress-nginx created
# serviceaccount/ingress-nginx created
# serviceaccount/ingress-nginx-admission created
# role.rbac.authorization.k8s.io/ingress-nginx created
# role.rbac.authorization.k8s.io/ingress-nginx-admission created
# clusterrole.rbac.authorization.k8s.io/ingress-nginx created
# clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
# rolebinding.rbac.authorization.k8s.io/ingress-nginx created
# rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
# clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
# clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
# configmap/ingress-nginx-controller created
# service/ingress-nginx-controller created
# service/ingress-nginx-controller-admission created
# deployment.apps/ingress-nginx-controller created
# job.batch/ingress-nginx-admission-create created
# job.batch/ingress-nginx-admission-patch created
# ingressclass.networking.k8s.io/nginx created
# validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created

# confirm
kubectl get deploy --namespace=ingress-nginx
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# ingress-nginx-controller   1/1     1            1           16m

kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       16m

```

---

### Install `Nginx Gateway Fabric`

```sh
# install resources
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f -
# customresourcedefinition.apiextensions.k8s.io/backendtlspolicies.gateway.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/grpcroutes.gateway.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/referencegrants.gateway.networking.k8s.io created

# Deploy the NGINX Gateway Fabric CRDs
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/crds.yaml
# customresourcedefinition.apiextensions.k8s.io/clientsettingspolicies.gateway.nginx.org serverside-applied
# customresourcedefinition.apiextensions.k8s.io/nginxgateways.gateway.nginx.org serverside-applied
# customresourcedefinition.apiextensions.k8s.io/nginxproxies.gateway.nginx.org serverside-applied
# customresourcedefinition.apiextensions.k8s.io/observabilitypolicies.gateway.nginx.org serverside-applied
# customresourcedefinition.apiextensions.k8s.io/snippetsfilters.gateway.nginx.org serverside-applied
# customresourcedefinition.apiextensions.k8s.io/upstreamsettingspolicies.gateway.nginx.org serverside-applied

# Deploys NGINX Gateway Fabric with NGINX OSS.
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.3.0/deploy/default/deploy.yaml
# namespace/nginx-gateway unchanged
# serviceaccount/nginx-gateway unchanged
# serviceaccount/nginx-gateway-cert-generator unchanged
# role.rbac.authorization.k8s.io/nginx-gateway-cert-generator unchanged
# clusterrole.rbac.authorization.k8s.io/nginx-gateway unchanged
# rolebinding.rbac.authorization.k8s.io/nginx-gateway-cert-generator unchanged
# clusterrolebinding.rbac.authorization.k8s.io/nginx-gateway unchanged
# service/nginx-gateway unchanged
# deployment.apps/nginx-gateway unchanged
# job.batch/nginx-gateway-cert-generator created
# gatewayclass.gateway.networking.k8s.io/nginx created
# nginxgateway.gateway.nginx.org/nginx-gateway-config created
# nginxproxy.gateway.nginx.org/nginx-gateway-proxy-config created

# confirm
kubectl get deploy -n nginx-gateway
# NAME            READY   UP-TO-DATE   AVAILABLE   AGE
# nginx-gateway   1/1     1            1           6m12s

kubectl get gatewayclass
# NAME    CONTROLLER                                   ACCEPTED   AGE
# nginx   gateway.nginx.org/nginx-gateway-controller   True       5m13s

```

---

### Install VPA

```sh
# Install VPA Custom Resource Definitions (CRDs)
# allow Kubernetes to recognize the custom resources that VPA uses to function properly.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/vpa-release-1.0/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
# customresourcedefinition.apiextensions.k8s.io/verticalpodautoscalercheckpoints.autoscaling.k8s.io created
# customresourcedefinition.apiextensions.k8s.io/verticalpodautoscalers.autoscaling.k8s.io created

# Install VPA Role-Based Access Control (RBAC)
# ensures that VPA has the appropriate permissions to operate within your Kubernetes cluster.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/vpa-release-1.0/vertical-pod-autoscaler/deploy/vpa-rbac.yaml
# clusterrole.rbac.authorization.k8s.io/system:metrics-reader created
# clusterrole.rbac.authorization.k8s.io/system:vpa-actor created
# clusterrole.rbac.authorization.k8s.io/system:vpa-status-actor created
# clusterrole.rbac.authorization.k8s.io/system:vpa-checkpoint-actor created
# clusterrole.rbac.authorization.k8s.io/system:evictioner created
# clusterrolebinding.rbac.authorization.k8s.io/system:metrics-reader created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-actor created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-status-actor created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-checkpoint-actor created
# clusterrole.rbac.authorization.k8s.io/system:vpa-target-reader created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-target-reader-binding created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-evictioner-binding created
# serviceaccount/vpa-admission-controller created
# serviceaccount/vpa-recommender created
# serviceaccount/vpa-updater created
# clusterrole.rbac.authorization.k8s.io/system:vpa-admission-controller created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-admission-controller created
# clusterrole.rbac.authorization.k8s.io/system:vpa-status-reader created
# clusterrolebinding.rbac.authorization.k8s.io/system:vpa-status-reader-binding created

# Clone the repository
git clone https://github.com/kubernetes/autoscaler.git

# Run the setup script
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# confirm
kubectl get deploy -n kube-system
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# vpa-admission-controller   1/1     1            1           4h37m
# vpa-recommender            1/1     1            1           4h37m
# vpa-updater                1/1     1            1           4h37m
```

---

### Install `MetalLB`

```sh
# update config
kubectl edit configmap -n kube-system kube-proxy
# find:
# ipvs:
#   strictARP: false
# replace:
# ipvs:
#   strictARP: true

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
# namespace/metallb-system created
# customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/configurationstates.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/servicebgpstatuses.metallb.io created
# customresourcedefinition.apiextensions.k8s.io/servicel2statuses.metallb.io created
# serviceaccount/controller created
# serviceaccount/speaker created
# role.rbac.authorization.k8s.io/controller created
# role.rbac.authorization.k8s.io/pod-lister created
# clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
# clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
# rolebinding.rbac.authorization.k8s.io/controller created
# rolebinding.rbac.authorization.k8s.io/pod-lister created
# clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
# clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
# configmap/metallb-excludel2 created
# secret/metallb-webhook-cert created
# service/metallb-webhook-service created
# deployment.apps/controller created
# daemonset.apps/speaker created
# validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created

# confirm
kubectl get pods -n metallb-system
# NAME                         READY   STATUS    RESTARTS   AGE
# controller-9c6cff498-bxxf7   1/1     Running   0          50s
# speaker-9xdrj                1/1     Running   0          50s
# speaker-fh4fg                1/1     Running   0          50s
# speaker-lr7qg                1/1     Running   0          50s

# Create IPAddressPool that MetalLB can assign from.
tee ~/metallb-ip-pool.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: web-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.210-192.168.10.220
EOF

kubectl apply -f ~/metallb-ip-pool.yaml
# ipaddresspool.metallb.io/web-pool created

kubectl get IPAddressPool web-pool -n metallb-system
# NAME       AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
# web-pool   true          false             ["192.168.10.210-192.168.10.220"]

# Create L2Advertisement to announce those IPs via ARP.
tee ~/metallb-l2adv.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: web-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - web-pool
EOF

kubectl apply -f ~/metallb-l2adv.yaml
# l2advertisement.metallb.io/web-l2 created

kubectl get L2Advertisement web-l2 -n metallb-system
# NAME     IPADDRESSPOOLS   IPADDRESSPOOL SELECTORS   INTERFACES
# web-l2   ["web-pool"]


# confirm: MetalLB assign an external IP to Nginx Gateway Service
kubectl get svc -n nginx-gateway
# NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-gateway   ClusterIP   10.111.194.40   <none>        443/TCP   34m
```

---
