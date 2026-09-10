# CKS: Istio - Sidecar Injection

[Back](../README.md)

- [CKS: Istio - Sidecar Injection](#cks-istio---sidecar-injection)
  - [Sidecar injection](#sidecar-injection)
  - [Lab: inject sidecar](#lab-inject-sidecar)

---

## Sidecar injection

- Two primary ways of **injecting** the Istio `sidecar` into a pod
  - Enable automatic Istio **sidecar injection** in the pod’s **namespace**
    - label: `istio-injection=enabled`
  - Automatic injection occurs **at the pod-level**.
    - any new pods that are created in that namespace **will automatically** have a sidecar **added** to them.
  - Manually using the `istioctl` **command**

---

## Lab: inject sidecar

- before

```sh
kubectl run web-app --image=nginx
# pod/web-app created

kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# web-app   1/1     Running   0          12s
```

- inject sidecar

```sh
# get ns label
kubectl get namespace default --show-labels
# NAME      STATUS   AGE    LABELS
# default   Active   236d   kubernetes.io/metadata.name=default

# enable injection
kubectl label namespace default istio-injection=enabled
# namespace/default labeled

# confirm
kubectl get namespace default --show-labels
# NAME      STATUS   AGE    LABELS
# default   Active   236d   istio-injection=enabled,kubernetes.io/metadata.name=default

# create new app
kubectl run web-app-new --image=nginx
# pod/web-app-new created

# confirm
kubectl get pods
# NAME          READY   STATUS    RESTARTS   AGE
# web-app       1/1     Running   0          3m11s
# web-app-new   2/2     Running   0          25s

kubectl describe pod web-app-new
# Init Containers:
#   istio-init:
#     Container ID:  containerd://67d748af1fea5570629050bde9fc06c3cb363defc66bb62429e89223d1dc3e58
#     Image:         docker.io/istio/proxyv2:1.31.0
# Containers:
#   web-app-new:
#     Container ID:   containerd://6715c945c1208433ed8cc1cc51457435502a52e1f3ed7c07af0d82e41499ec99
#     Image:          nginx
#   istio-proxy:
#     Container ID:  containerd://de3402446616fb5d2acfb1a1caeec85a6c7e415c2bec4042c2ba5abbfa14d0a1
#     Image:         docker.io/istio/proxyv2:1.31.0
```
