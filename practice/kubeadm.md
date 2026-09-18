# Practices - kubeadm

[Back](../README.md)

- [Practices - kubeadm](#practices---kubeadm)
  - [harsh check](#harsh-check)

---

## harsh check

- question:
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
