# Practices - Verify Binary

[Back](../../README.md)

- [Practices - Verify Binary](#practices---verify-binary)
  - [Binary: `kubelet`](#binary-kubelet)
  - [Binary: `kubectl` current version](#binary-kubectl-current-version)
  - [Binary: verify tar file](#binary-verify-tar-file)
  - [Binary: download and checkrum latest `kubectl`](#binary-download-and-checkrum-latest-kubectl)
  - [apiserver: flag(killer A)](#apiserver-flagkiller-a)

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
