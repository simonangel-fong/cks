# Practices - Verify Binary

[Back](../../README.md)

- [Practices - Verify Binary](#practices---verify-binary)
  - [Shortcut](#shortcut)
    - [Kubeconfig](#kubeconfig)
    - [Kubelet](#kubelet)
    - [kube-apiserver](#kube-apiserver)
  - [Binary: `kubelet`](#binary-kubelet)
  - [Binary: `kubectl` current version](#binary-kubectl-current-version)
  - [Binary: verify tar file](#binary-verify-tar-file)
  - [Binary: download and checkrum latest `kubectl`](#binary-download-and-checkrum-latest-kubectl)
  - [apiserver: flag(killer A)](#apiserver-flagkiller-a)
  - [binary(killer B)](#binarykiller-b)
  - [API Server(killer B)](#api-serverkiller-b)
  - [Checksum](#checksum)
  - [cluster config - controller](#cluster-config---controller)

---

## Shortcut

### Kubeconfig

| CMD                                  | DESC                |
| ------------------------------------ | ------------------- |
| `kubectl --kubeconfig=/path/to/conf` | specify config file |

- enforce using config file

```sh
# unset envvar
unset KUBECONFIG
# remove default config
mv ~/.kube/config ~/.kube/config.bak
```

---

### Kubelet

- kubelet config file:
  - `/var/lib/kubelet/config.yaml`
- kubeconfig file for kubelet
  - `/etc/kubernetes/kubelet.conf`
- seccomp profiles
  - `/var/lib/kubelet/seccomp`
- default host directory for seccomp
  - `/var/lib/kubelet/seccomp/profiles`

---

### kube-apiserver

- config file path:
  - `etc/kubernetes/manifests/kube-apiserver.yaml`

---

## Binary: `kubelet`

- task:
  - download the `kubelet` binary url `https://dl.k8s.io/v1.37.0/bin/linux/amd64/kubelet`
  - compare sha hashes url `https://dl.k8s.io/v1.37.0/bin/linux/amd64/kubelet.sha256`

---

- solution
  - ref: https://kubernetes.io/releases/download/

```sh
wget https://dl.k8s.io/v1.37.0/bin/linux/amd64/kubelet

ls -lh kubelet
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin 59M Aug 26 12:28 kubelet

sha256sum kubelet
# ee554f77da57ad40a5d5f8625ac9c4af8b75d9d5a259367a885e5e816954b044  kubelet

cat kubelet.sha256; echo
# ee554f77da57ad40a5d5f8625ac9c4af8b75d9d5a259367a885e5e816954b044
```

---

## Binary: `kubectl` current version

- task:
  - get sha256 of the current kubectl

```sh
which kubectl
# /usr/bin/kubectl

kubectl version

sha256sum /usr/bin/kubectl
# 8b8f088da2dab964f853b38464033b1be15ede2839eca751482357c45abdd05a  /usr/bin/kubectl
```

---

## Binary: verify tar file

- task:
  - download tar file from url `https://dl.k8s.io/v1.31.0/kubernetes-server-linux-amd64.tar.gz`
  - checksume 256 of the `kubelet`

```sh
wget https://dl.k8s.io/v1.31.0/kubernetes-server-linux-amd64.tar.gz

tar -xvf kubernetes-server-linux-amd64.tar.gz

# find kubelet
ls -lh kubernetes/server/bin/kubelet
# -rwxr-xr-x 1 root root 74M Aug 13  2024 kubernetes/server/bin/kubelet

sha256sum kubernetes/server/bin/kubelet
# 39e7f1c61c8389ea7680690f8bd5dd733672fa16875ae598df0fd8c205df57a9  kubernetes/server/bin/kubele
```

---

## Binary: download and checkrum latest `kubectl`

- ref: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux

```sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

ls
# kubectl  kubectl.sha256

# Validate
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# kubectl: OK
```

---

## apiserver: flag(killer A)

- task:
  - You received a list from the DevSecOps team which performed a security investigation of the cluster. The list states the following about the apiserver setup:
    - **Accessible through a NodePort Service**
  - Change the apiserver setup so that:
    - **Accessible through a ClusterIP Service**
  - ℹ️ Use sudo -i to become root which may be required for this question

```sh
sudo -i

# config apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# find
# --kubernetes-service-node-port
# replace
# --kubernetes-service-node-port=0

# confim
grep kubernetes-service-node-port /etc/kubernetes/manifests/kube-apiserver.yaml
# --kubernetes-service-node-port=0

# confirm apiserver working
kubectl get node


# update existing svc
k get svc
# NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
# default       kubernetes   NodePort    10.96.0.1    <none>        443/TCP                  76s

k edit svc kubernetes
# update:
# type: ClusterIP

# confirm
k get svc -A
# NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
# default       kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  3m36s
```

> Note:
> Steps:
>
> 1. refer to the flags in documentation, keyword "kube-apiserver"
> 2. update flag
> 3. confirm until apiserver rerun.

---

## binary(killer B)

- task:
  - There are four Kubernetes server binaries located at `/course/6/binaries`. You're provided with the following verified sha512 values for these:
  - kube-apiserver: `f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c`
  - kube-controller-manager: `60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60`
  - kube-proxy: `52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6`
  - kubelet: `4be40f2440619e990897cf956c32800dc96c2c983bf64519854a3309fa5aa21827991559f9c44595098e27e6f2ee4d64a3fdec6baba8a177881f20e3ec61e26c`
  - Delete those binaries that don't match the sha512 values above.

---

- solution:

```sh
cd /course/6/binaries
ll

sha512sum kube-apiserver | grep f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c
sha512sum kube-controller-manager | grep 60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60
# return none
sha512sum kube-proxy | grep 52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6
sha512sum kubelet | grep 4be40f2440619e990897cf956c32800dc96c2c983bf64519854a3309fa5aa21827991559f9c44595098e27e6f2ee4d64a3fdec6baba8a177881f20e3ec61e26c
# return none

```

---

## API Server(killer B)

- task
  - Set the TLS min version of the Apiserver to version 1.3.
  - Afterwards use `curl --tls-max 1.2 --tlsv1.2` to call the Apiserver and write the full output including any errors to `/course/15/curl.log`.

---

- solution:

```sh
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# --tls-min-version=VersionTLS13

# confirm
crictl ps

curl --tls-max 1.2 --tlsv1.2 https://localhost:6443
# show error

# write
vi /course/15/curl.log

# confirm
cat /course/15/curl.log
```

---

## Checksum

Task
Please exit from cluster2-controlplane and ensure that you are in `cluster1-controlplane` for the subsequent question.

Three binary packages have been placed in `/root/binary-verification/`, with only one being authentic.

Tasks:

Review the official checksum in `official-checksum.sha256`.
Verify each binary package (`v1.tar`, `v2.tar`, `v3.tar`) against the official checksum.
Determine which binary package is authentic.
Complete the verification report at `/root/binary-verification-report.txt` with the following details:

- The official checksum value
- Verification results for each binary (AUTHENTIC or TAMPERED, along with the actual checksum)
- Identification of the authentic binary
- Binary packages to verify:
  - v1.tar
  - v2.tar
  - v3.tar

---

- **Solution**

Binary Verification Solution

- Step 1: Check the Official Checksum

```sh
cd /root/binary-verification
cat official-checksum.sha256
```

- Step 2: Calculate Checksums for Each Binary

```sh
# Calculate checksum for v1.tar
sha256sum v1.tar

# Calculate checksum for v2.tar
sha256sum v2.tar

# Calculate checksum for v3.tar
sha256sum v3.tar
```

- Step 3: Compare and Complete the Report

```sh
# Edit the report template:
vi /root/binary-verification-report.txt

# Fill in the following details:
# Example Completed Report:
# Kubernetes Binary Verification Report
# ====================================
# Fri Oct 3 07:26:17 AM EDT 2025

# OFFICIAL CHECKSUM: 8739dd0797f162c7d8b87c4d3213d074f91d9cbf0bdf4cba73afa0b5becb075c correct-binary.tar

# VERIFICATION RESULTS:
# v1.tar: 9a0b036a9b0885a7521bc63c65a7baf2ce63c52ca1c86c56ff101e07762be334
# v2.tar: 8739dd0797f162c7d8b87c4d3213d074f91d9cbf0bdf4cba73afa0b5becb075c
# v3.tar: 9431b841b7d5201ea6687ebbba02f78ed3854613bd307fca32d871c0004f7469

# AUTHENTIC BINARY: v2.tar

```

---

## cluster config - controller

Task
SSH into the cluster2-controlplane to address the following tasks:

Configure the kube-controller-manager to use the `--use-service-account-credentials` flag.
Set the `--terminated-pod-gc-threshold` to `50`.
The admin kubeconfig file for this cluster is located at: `/root/controller-config/admin.conf`

Additionally, please utilize this kubeconfig file to delete the cluster role named '`legacy-cluster-role`'.

Confirm `kube-controller-manager` returns to Running before continuing

The backup of the original kube-controller-manager configuration is located at /tmp/kube-controller-manager-bak.yaml.

---

- solution:

```sh
ssh cluster2-controlplane

vi /etc/kubernetes/manifests/kube-controller-manager.yaml
# containers:
# - command:
#   - kube-controller-manager
#   - --use-service-account-credentials=true
#   - --terminated-pod-gc-threshold=50

# confirm restart
crictl ps -a | grep controller-manager
journalctl -u kubelet -n 50 --no-pager

# remove clusterrole
kubectl --kubeconfig=/root/controller-config/admin.conf delete clusterrole legacy-cluster-role

kubectl --kubeconfig=/root/controller-config/admin.conf get po -n kube-system | grep controller-manager
```

---
