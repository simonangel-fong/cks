# Practices - Pod Security Context AppArmor

[Back](../../README.md)

- [Practices - Pod Security Context AppArmor](#practices---pod-security-context-apparmor)
  - [Pod Security Context: AppArmor](#pod-security-context-apparmor)
  - [AppArmor (killer A)](#apparmor-killer-a)

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

---

## AppArmor (killer A)

- task:
  - Some containers need to run more securely. There is an existing AppArmor profile located at `/course/9/profile` on cks7262 for this.
  - Install the AppArmor profile on node node01.
  - Connect using ssh node1 from controlplane
  - Add label `security=apparmor` to the node
  - Create a Deployment named `apparmor` in Namespace `default` with:
    - One replica of image `nginx:1-alpine`
    - NodeSelector for `security=apparmor`
    - Single container named `c1` with the `AppArmor` profile enabled only for this container
  - The Pod might not run properly with the profile enabled. Write the logs of the Pod into `/course/9/logs` on controlplane so another team can work on getting the application running.

ℹ️ Use sudo -i to become root which may be required for this question

---

- solution

```sh
# node01
ssh node01
# create aa profile
vi /etc/apparmor.d/course-9-profile
apparmor_parser -r /etc/apparmor.d/course-9-profile

aa-status | grep '<profile-name>'

# controlplane
# label
kubectl label node node01 security=apparmor --overwrite
# confirm
kubectl get node node01 --show-labels

# create deploy
k create deploy apparmor -n default --image=nginx:1-alpine --dry-run=client -o yaml > aa.yaml
```

```yaml
# vi aa.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
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
      nodeSelector:
        security: apparmor
      containers:
        - name: c1
          image: nginx:1-alpine
          securityContext:
            appArmorProfile:
              type: Localhost
              localhostProfile: <profile-name>
```

```sh
kubectl apply -f aa.yaml
kubectl get pods -o wide

kubectl logs -l app=apparmor --all-containers > /course/9/logs

# confirm
cat /course/9/logs
```
