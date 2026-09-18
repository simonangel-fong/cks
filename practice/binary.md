# Practices - binary

[Back](../README.md)

- [Practices - binary](#practices---binary)
  - [verify binary](#verify-binary)
  - [verify current version](#verify-current-version)
  - [verify tar file](#verify-tar-file)
  - [checkrum kubelet](#checkrum-kubelet)

---

## verify binary

- task:
  - download the kubelet binary in the same version
  - compare sha hashes

---

- solution
  - ref: https://kubernetes.io/releases/download/

```sh
wget https://dl.k8s.io/v1.37.0/bin/linux/amd64/kubelet

ls -lh kubelet
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin 59M Aug 26 12:28 kubelet

sha256sum kubelet
# ee554f77da57ad40a5d5f8625ac9c4af8b75d9d5a259367a885e5e816954b044  kubelet

curl https://dl.k8s.io/v1.37.0/bin/linux/amd64/kubelet.sha256; echo
# ee554f77da57ad40a5d5f8625ac9c4af8b75d9d5a259367a885e5e816954b044
```

---

## verify current version

```sh
kubectl version

sha256sum $(which kubectl)
# 874d5e72dbb819f43cff16bcd1e4f8bac5b7f2361fe1e55049b0a6c676fb0cbf  /usr/bin/kubectl
```

---

## verify tar file


```sh
wget https://dl.k8s.io/v1.31.0/kubernetes-server-linux-amd64.tar.gz

tar -xvf kubernetes-server-linux-amd64.tar.gz

sha512sum kubernetes/server/bin/kubelet
# ff046bb2fd64ccf105f0b84ab8d26bab3b28955119d5e1be6bfdc2f9cea7afe4277d43ea91d5e4da020cc019fef629c8157e12c6a27b0dd0a0d04cb14f29a08b  kubernetes/server/bin/kubelet
```

---

## checkrum kubelet

- ref: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux

```sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# kubectl: OK
```