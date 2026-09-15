# Practices - pod security context

[Back](../README.md)

- [Practices - pod security context](#practices---pod-security-context)
  - [root file system](#root-file-system)
  - [debug nginx fs](#debug-nginx-fs)

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