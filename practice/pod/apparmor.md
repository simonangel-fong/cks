# Practices - Pod Security Context AppArmor

[Back](../README.md)

- [Practices - Pod Security Context AppArmor](#practices---pod-security-context-apparmor)
  - [Pod Security Context: AppArmor](#pod-security-context-apparmor)

---

## Pod Security Context: AppArmor

- ref: https://kubernetes.io/docs/tutorials/security/apparmor/
- task:
  - exiting apparmor profile path: `/etc/apparmor.d/k8s-apparmor-deny-write`
  - create a deploy named `apparmor` and secure using the apparmor profile
    - image: `busybox:1.28`

- setup env:

```sh
# worker node: node01
sudo tee /etc/apparmor.d/k8s-apparmor-deny-write<<EOF
#include <tunables/global>

profile k8s-apparmor-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
EOF
```

- solution

```sh
# module is enabled
cat /sys/module/apparmor/parameters/enabled
# Y

# confirm aa status by listing profile
sudo aa-status

# ##############################
# create a sample profile
# ##############################
# in worker node
ssh node01
# create profile
sudo apparmor_parser -rq /etc/apparmor.d/k8s-apparmor-deny-write

# confirm
sudo aa-status | grep k8s-apparmor-deny-write
  #  k8s-apparmor-deny-write
```

```yaml
# vi apparmor.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: apparmor
  name: apparmor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apparmor
  template:
    metadata:
      labels:
        app: apparmor
    spec:
      containers:
        - name: apparmor
          image: busybox:1.28
          command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 1h"]
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: k8s-apparmor-deny-write
```

```sh
kubectl create -f apparmor.yaml
# deployment.apps/apparmor created

kubectl get po
# NAME                        READY   STATUS        RESTARTS   AGE
# apparmor-79fc79dc45-8dqvd   1/1     Running       0          44s

# test
kubectl exec apparmor-79fc79dc45-8dqvd -- touch /tmp/test
# touch: /tmp/test: Permission denied
# command terminated with exit code 1
```
