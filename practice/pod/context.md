# Practices - Pod Security Context

[Back](../../README.md)

- [Practices - Pod Security Context](#practices---pod-security-context)
  - [Security Context: Non-Root User](#security-context-non-root-user)
  - [Security Context: User id \& Group id](#security-context-user-id--group-id)
  - [Security Context: Least privileges](#security-context-least-privileges)
  - [Security Context: Read only root file system](#security-context-read-only-root-file-system)
  - [Security Context: Make the container immutable](#security-context-make-the-container-immutable)

---

- Security Context
  - Privileged Pods, Capabilities, readOnlyRootFilesystem (immutability)

## Security Context: Non-Root User

- task:
  - create a pod
    - named `web-app`
    - image: `bitnami/nginx`
    - run as non-root user

- solution

```yaml
# vi nonroot.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
    - name: web-app
      image: bitnami/nginx
      securityContext:
        runAsNonRoot: true
```

```sh
k apply -f nonroot.yaml
kubectl get po
# NAME      READY   STATUS    RESTARTS   AGE
# web-app   1/1     Running   0          86s

kubectl exec -it web-app -- id
# uid=1001 gid=0(root) groups=0(root)
```

---

## Security Context: User id & Group id

- task:
  - create po named `user-id`:
    - user id = 2000
    - group id = 2000
    - label: `app: user-id`

- solution:

```yaml
# vi user-id.yaml
apiVersion: v1
kind: Pod
metadata:
  name: user-id
  labels:
    app: user-id
spec:
  securityContext:
    runAsUser: 2000
    runAsGroup: 2000
  containers:
    - name: user-id
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
```

```sh
kubectl apply -f user-id.yaml
kubectl exec -it user-id -- id
# uid=2000 gid=2000 groups=2000
```

---

## Security Context: Least privileges

- task:
  - create a pod named `least-privilege`
    - iamge: busybox
    - user id: 2000
    - group id: 2000
    - non root user: true
    - Escalation: false
    - privileged: false
    - drop all capabilities

- solution:

```yaml
# vi least-permission.yaml
apiVersion: v1
kind: Pod
metadata:
  name: least-privilege
spec:
  containers:
    - name: least-privilege
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        privileged: false
        runAsUser: 2000
        runAsGroup: 2000
        capabilities:
          drop:
            - ALL
```

```sh
k apply -f least-permission.yaml

# test
kubectl exec -it least-privilege -- id
# uid=2000 gid=2000 groups=2000

```

> least privileges: `allowPrivilegeEscalation`, `privileged`, `runAsNonRoot`, dropped `capabilities`

---

## Security Context: Read only root file system

- task:
  - create a pod named `rofs` with image `busybox` command `sleep 1d`
  - root fs should be read-only

---

- solution

```yaml
# vi rofs.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rofs
spec:
  containers:
    - name: rofs
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1d"]
      securityContext:
        readOnlyRootFilesystem: true
```

```sh
k apply -f rofs.yaml

# confirm
k get pod
# NAME   READY   STATUS    RESTARTS   AGE
# rofs   1/1     Running   0          2m7s

kubectl exec -it rofs -- touch /tmp/text.txt
# touch: /tmp/text.txt: Read-only file system
# command terminated with exit code 1
```

---

## Security Context: Make the container immutable

- task:
  - deploy `rofs` in `moon` ns does not work with `readOnlyRootFilesystem`
  - fix it
  - hint: nginx need to write /var/cache/nginx and /var/run

- setup env:

```yaml
# vi nginx-ro.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ro
  namespace: moon
spec:
  selector:
    matchLabels:
      app: nginx-ro
  template:
    metadata:
      labels:
        app: nginx-ro
    spec:
      containers:
        - name: nginx-ro
          image: nginx
          securityContext:
            readOnlyRootFilesystem: true
```

```sh
kubectl apply -f nginx-ro.yaml
kubectl get po -n moon
# NAME                        READY   STATUS   RESTARTS      AGE
# nginx-ro-67f6788fdf-tvnd2   0/1     Error    2 (25s ago)   28s
```

---

- solution:

```yaml
# vi nginx-ro.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ro
  namespace: moon
spec:
  selector:
    matchLabels:
      app: nginx-ro
  template:
    metadata:
      labels:
        app: nginx-ro
    spec:
      containers:
        - name: nginx-ro
          image: nginx
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: cache-volume
              mountPath: /var/cache/nginx
            - name: runtime-volume
              mountPath: /var/run
      volumes:
        - name: cache-volume
          emptyDir: {}
        - name: runtime-volume
          emptyDir: {}
```

```sh
kubectl apply -f nginx-ro.yaml

kubectl get po -n moon
# NAME                       READY   STATUS    RESTARTS   AGE
# nginx-ro-c6b6db6b7-bn56z   1/1     Running   0          9s
```
