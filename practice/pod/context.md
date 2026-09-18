# Practices - Security Context

[Back](../../README.md)

- [Practices - Security Context](#practices---security-context)
  - [pod: Non-Root User](#pod-non-root-user)
  - [pod: user id \& group id](#pod-user-id--group-id)
  - [pod: Pod with least privileges](#pod-pod-with-least-privileges)
  - [root file system](#root-file-system)
  - [debug nginx fs](#debug-nginx-fs)
  - [Context: Make the container immutable](#context-make-the-container-immutable)

---

- Security Context
  - Privileged Pods, Capabilities, readOnlyRootFilesystem (immutability)

## pod: Non-Root User

- task:
  - create a pod named `web-app` and run as non-root user

- solution

```yaml
# vi non-root-po.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web-app
  name: web-app
spec:
  containers:
    - name: web-app
      image: bitnami/nginx
  securityContext:
    runAsNonRoot: true
```

```sh
k apply -f non-root-po.yaml
```

---

## pod: user id & group id

- task:
  - create po named `pod-user-id`:
    - user id = 1000
    - group id = 1000
    - label: `app: pod-user-id`

- solution:

```yaml
# vi pod-user-id.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-user-id
  labels:
    app: pod-user-id
spec:
  containers:
    - image: busybox
      name: pod-user-id
      command: ["sh", "-c", "sleep 1d"]
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
```

```sh
k apply -f pod-user-id.yaml
k exec -it pod-user-id -- id
# uid=1000 gid=1000 groups=1000
```

---

## pod: Pod with least privileges

- task:
  - create a pod named `pod-least-privilege`

- solution:

```yaml
# vi pod-least-privilege.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-least-privilege
spec:
  containers:
    - name: pod-least-privilege
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1d"]
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
```

```sh
k apply -f pod-least-privilege.yaml

# test
k exec -it pod-least-privilege -- sudo apt update
# error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "42e054dd20abcdcb202a15bc056d1fc16cb8842dcb2f3289b5341cc0b51ae45e": OCI runtime exec failed: exec failed: unable to start container process: exec: "sudo": executable file not found in $PATH
```

> least privileges: `allowPrivilegeEscalation`, `privileged`, `runAsNonRoot`, dropped `capabilities`

---

## root file system

- task:
  - create a pod named `pod-ro` in ns `sun` with image `busybox`
  - `sleep 1d`
  - root fs should be read-only

---

- solution

```yaml
# vi root-fs.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-ro
  namespace: sun
spec:
  containers:
    - name: pod-ro
      image: busybox
      command: ["sh", "-c", "sleep 1d"]
      securityContext:
        readOnlyRootFilesystem: true
```

```sh
k create ns sun
k apply -f root-fs.yaml

# confirm
k describe pod pod-ro -n sun

k exec -it pod-ro -n sun -- touch /tmp/test.txt
# touch: /tmp/test.txt: Read-only file system
# command terminated with exit code 1
```

---

## debug nginx fs

- task:
  - deploy `web4.0` in ns `moon` does not work with `readOnlyRootFilesystem`
  - add an emptyDir volume

---

- setup env:

```sh
k create ns moon
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web4.0
  namespace: moon
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web4.0
  template:
    metadata:
      labels:
        app: web4.0
    spec:
      containers:
        - name: web
          image: nginx
          securityContext:
            readOnlyRootFilesystem: true
EOF

# confirm fail
k get po -n moon
# NAME                      READY   STATUS   RESTARTS      AGE
# web4.0-567f9979d9-57j82   0/1     Error    2 (26s ago)   29s
# web4.0-567f9979d9-cgmjm   0/1     Error    2 (26s ago)   29s
```

---

- solution

```sh
# confirm
k get po -n moon
# NAME                      READY   STATUS   RESTARTS      AGE
# web4.0-567f9979d9-57j82   0/1     Error    2 (26s ago)   29s
# web4.0-567f9979d9-cgmjm   0/1     Error    2 (26s ago)   29s

# diagnose
k describe po web4.0-567f9979d9-cgmjm -n moon
#   Warning  BackOff    39s (x5 over 2m8s)   kubelet            spec.containers{web}: Back-off restarting failed container web in pod web4.0-567f9979d9-cgmjm_moon(03ab6f21-5dbd-4c44-a37c-749f3ecf16ad)

# find the error: cannot create /etc/data.log: read-only file system
k logs web4.0-567f9979d9-cgmjm -n moon


k get deploy web4.0 -n moon -o yaml > web4.0.yaml

vi web4.0.yaml
# spec:
#     spec:
#       volumes:
#       - name: temp
#         emptyDir: {}
#       containers:
#       - image: nginx
#         name: nginx
#         securityContext:
#           readOnlyRootFilesystem: true
#         volumeMounts:
#           - name: temp
#             mountPath: /etc

kubectl replace --force -f web4.0.yaml

kubectl rollout restart deploy web4.0 -n moon

# confirm
kubectl get po -n moon
```

---

## Context: Make the container immutable

```yaml
# Create a Pod with ReadOnlyRooFileSystem security context
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: immutable-pod
  name: immutable-pod
spec:
  containers:
    - image: nginx
      name: immutable-pod
      securityContext:
        readOnlyRootFilesystem: true
```

```yaml
# vi pod-immutable-fs.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.21.6
      securityContext:
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: nginx-run
          mountPath: /var/cache
  volumes:
    - name: nginx-run
      emptyDir: {}
```
