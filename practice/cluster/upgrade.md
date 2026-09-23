# Practice: Upgrade Cluster

[back](../../README.md)

- [Practice: Upgrade Cluster](#practice-upgrade-cluster)
  - [Shortcut](#shortcut)
  - [Upgrade controlplane](#upgrade-controlplane)
  - [Upgrade worker noded](#upgrade-worker-noded)
  - [Upgrade(killer B)](#upgradekiller-b)

---

## Shortcut

- Kubernetes Cluster Upgrade
  - Learn to upgrade both control plane and worker nodes using kubeadm

- common troubleshooting
  - kubectl down:
    - check kubelet, systemctl status
    - check kubelet log, journalctl -u kubelet
    - check log files apiserver, tail /var/log/pods/apiserver
    - confirm with document, e.g., flag; space issue: `flag = value`
    - backup config file
    - fix config file
    - confirm, kubectl get

---

## Upgrade controlplane

- 1. https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
-

- task:
  - upgrade from 1.35 to 1.36

```sh
# ##############################
# update index
# ##############################
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt-cache madison kubeadm
# kubeadm | 1.36.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.36/deb  Packages

# ##############################
# upgrade kubeadm
# ##############################
sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.36.4-1.1' && \
sudo apt-mark hold kubeadm

kubeadm version

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.4


# ##############################
# kubelet kubectl
# ##############################
kubectl get node
# controlplane
kubectl drain controlplane --ignore-daemonsets

sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.36.4-1.1' kubectl='1.36.4-1.1' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon controlplane

k get node
# NAME           STATUS   ROLES           AGE     VERSION
# controlplane   Ready    control-plane   4d23h   v1.36.4
# node01         Ready    <none>          15h     v1.35.8
```

---

## Upgrade worker noded

```sh
# ##############################
# update index
# ##############################
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt-cache madison kubeadm
# kubeadm | 1.36.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.36/deb  Packages

# ##############################
# upgrade kubeadm
# ##############################
sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.36.4-1.1' && \
sudo apt-mark hold kubeadm

sudo kubeadm upgrade node

kubeadm version

# ##############################
# Upgrade kubelet and kubectl
# ##############################
hostname
# node01

# controlplane
kubectl drain node01 --ignore-daemonsets

sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.36.4-1.1' kubectl='1.36.4-1.1' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

# controlplane
kubectl uncordon node01
```

---

## Upgrade(killer B)

- task:
  - The cluster is running Kubernetes `1.34.8`, update it to `1.35.6`.
  - Use `apt` package manager and `kubeadm` for this.
  - Use ssh node1 from master to connect to the worker node.

---

- solution

- controlplane

```sh
sudo apt update
sudo apt-cache madison kubeadm

sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.35.6-1.1' && \
sudo apt-mark hold kubeadm

kubeadm upgrade plan
kubeadm upgrade apply v1.35.6 -y

kubectl drain controlplane --ignore-daemonsets

sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.35.6-1.1' kubectl='1.35.6-1.1' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon controlplane
```

---

- worker

```sh
sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.35.6-1.1' && \
sudo apt-mark hold kubeadm

sudo kubeadm upgrade node

# controlplane
kubectl drain node1 --ignore-daemonsets


sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.35.6-1.1' kubectl='1.35.6-1.1' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon node1
```
