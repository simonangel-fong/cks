# CKS: ns - Pod Security Standard

[Back](../README.md)

- [CKS: ns - Pod Security Standard](#cks-ns---pod-security-standard)
  - [Pod Security Standard](#pod-security-standard)
    - [Declarative](#declarative)
  - [`Pod Security Admission (PSA)`](#pod-security-admission-psa)
  - [Lab: PSS](#lab-pss)
    - [PSS - privileged](#pss---privileged)
    - [PSS - baseline](#pss---baseline)
    - [PSS - restricted](#pss---restricted)
    - [### PSS - restricted pod](#-pss---restricted-pod)

---

## Pod Security Standard

- `Pod Security Standards (PSS)`
  - **built-in policy definitions** that specify how pods should be isolated and secured **based on predefined risk levels**.
  - defined at a **namespace level**.
- The Three Security Profiles
  - `Privileged`:
    - Offers **completely unrestricted access** and allows known **privilege escalations**;
    - used for **trusted system-level** or **infrastructure workloads**.
  - `Baseline`:
    - **Prevents** known **privilege escalations** and **blocks** access to **sensitive host features** while allowing default pod configurations.
    - prevent:
      - Privileged Pod
      - HostPath volumes and HostPorts
      - Sharing the host namespaces.
  - `Restricted`:
    - Follows **strict pod hardening** best practices, such as requiring non-root execution and limiting capabilities, to reduce the attack surface.

- Labels modes:
  - `enforce`
    - blocks non-compliant pods
  - `audit`:
    - logs violations
  - `warn`:
    - alerts users

---

### Declarative

- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: my-privileged-namespace
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
---
apiVersion: v1
kind: Namespace
metadata:
  name: my-baseline-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: latest
---
apiVersion: v1
kind: Namespace
metadata:
  name: my-restricted-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

---

## `Pod Security Admission (PSA)`

- `Pod Security Admission (PSA)`:
  - A built-in **admission controller** that **evaluates and enforces** `PSS` standards **at the namespace level**.
  - When a pod is created, PSA checks if it complies with the security policies set at the namespace level.

---

## Lab: PSS

### PSS - privileged

```sh
# #################################
# privileged ns
# #################################
# create ns
kubectl create ns privileged-ns
# namespace/privileged-ns created

# label ns
kubectl label namespace privileged-ns pod-security.kubernetes.io/enforce=privileged
# namespace/privileged-ns labeled

# create privileged pod
kubectl run privileged-pod --image=nginx --privileged -n privileged-ns
# pod/privileged-pod created

# create default pod
kubectl run normal-pod --image=nginx -n privileged-ns
# pod/normal-pod created

# confirm
kubectl get po -n privileged-ns
# NAME             READY   STATUS    RESTARTS   AGE
# normal-pod       1/1     Running   0          23s
# privileged-pod   1/1     Running   0          33s
```

---

### PSS - baseline

```sh
# #################################
# baseline ns
# #################################
# create ns
kubectl create ns baseline-ns
# namespace/baseline-ns created

# label ns
kubectl label namespace baseline-ns pod-security.kubernetes.io/enforce=baseline
# namespace/baseline-ns labeled

# Privileged Pod
kubectl run privileged-pod --image=nginx --privileged -n baseline-ns
# Error from server (Forbidden): pods "privileged-pod" is forbidden: violates PodSecurity "baseline:latest": privileged (container "privileged-pod" must not set securityContext.privileged=true)

# Default Config Pod
kubectl run normal-pod --image=nginx -n baseline-ns
# pod/normal-pod created

# confirm
kubectl get po -n baseline-ns
# NAME         READY   STATUS    RESTARTS   AGE
# normal-pod   1/1     Running   0          4s
```

---

### PSS - restricted

```sh
# #################################
# restricted ns
# #################################
# create ns
kubectl create ns restricted-ns
# namespace/restricted-ns created

# label ns
kubectl label namespace restricted-ns pod-security.kubernetes.io/enforce=restricted
# namespace/restricted-ns labeled

# Privileged Pod
kubectl run privileged-pod --image=nginx --privileged -n restricted-ns
# Error from server (Forbidden): pods "privileged-pod" is forbidden: violates PodSecurity "restricted:latest": privileged (container "privileged-pod" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "privileged-pod" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "privileged-pod" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "privileged-pod" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "privileged-pod" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")

# Default Config Pod
kubectl run normal-pod --image=nginx -n restricted-ns
# Error from server (Forbidden): pods "normal-pod" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "normal-pod" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "normal-pod" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "normal-pod" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "normal-pod" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")

# confirm
kubectl get po -n restricted-ns
# No resources found in restricted-ns namespace.
```

---

### ### PSS - restricted pod

```sh
# pod without user id
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod-root
  namespace: restricted-ns
spec:
  containers:
  - name: secure-container
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# pod/restricted-pod-root created

# confirm
kubectl get pods restricted-pod-root -n restricted-ns
# NAME                  READY   STATUS                       RESTARTS   AGE
# restricted-pod-root   0/1     CreateContainerConfigError   0          2m31s

kubectl describe pods restricted-pod-root -n restricted-ns
# Events:
#   Type     Reason     Age                   From               Message
#   ----     ------     ----                  ----               -------
#   Warning  Failed     7s (x14 over 2m57s)   kubelet            Error: container has runAsNonRoot and image will run as root (pod: "restricted-pod-root_restricted-ns(fab17d5f-a671-40fa-89e5-87678ed925ef)", container: secure-container)

# pod with user id
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: restricted-ns
spec:
  containers:
  - name: secure-container
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 1001
      runAsGroup: 1001
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# pod/restricted-pod created

# confirm
kubectl get pods restricted-pod -n restricted-ns
# NAME             READY   STATUS    RESTARTS   AGE
# restricted-pod   1/1     Running   0          60s

kubectl exec -it restricted-pod -n restricted-ns -- sh
id
# uid=1001 gid=1001 groups=1001

```
