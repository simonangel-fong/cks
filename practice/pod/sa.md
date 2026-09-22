# Practices - SA

[Back](../../README.md)

- [Practices - SA](#practices---sa)
  - [SA: apply to pod](#sa-apply-to-pod)
  - [SA: disable token](#sa-disable-token)
  - [SA: mount token expire(killer A)](#sa-mount-token-expirekiller-a)

---

- Service Account + Projected Volumes
  - Know how to **create** `service accounts` with auto **mounting token** as disabled.
  - Be familiar with mounting volume sources like SA using `Projected Volumes`.

## SA: apply to pod

- task:
  - create ns `ns-secure`
  - create secret named `sec1` with kv pair `password=admin@234`
  - create secret named `sec2` with file `hosts=/etc/hosts`
  - create service account: `secret-manager`
  - create a pod named `secret-manager`
    - image: `httpd:alpine`
    - sa: `secret-manager`
    - mount secret `sec1` as env var `SEC1`
    - mount secret `sec2` in the read-only under `/etc/secret/sec2`

---

- solution

```sh
k create ns ns-secure
k -n ns-secure create secret generic sec1 --from-literal=password=admin@234
k -n ns-secure create secret generic sec2 --from-file=/etc/hosts
k -n ns-secure create sa secret-manager
```

```yaml
# vi secret-manager.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-manager
  namespace: ns-secure
spec:
  serviceAccountName: secret-manager
  containers:
    - name: secret-manager
      image: httpd:alpine
      ports:
        - containerPort: 80
      env:
        - name: SEC1
          valueFrom:
            secretKeyRef:
              name: sec1
              key: password
      volumeMounts:
        - name: sec2
          mountPath: "/etc/secret"
          readOnly: true
  volumes:
    - name: sec2
      secret:
        secretName: sec2
        items:
          - key: hosts
            path: sec2
```

```sh
k apply -f secret-manager.yaml
# pod/secret-manager created

# confirm
k describe pod/secret-manager -n ns-secure

k exec -it secret-manager -n ns-secure -- sh
echo $SEC1
# admin@234
cat /etc/secret/sec2
# 127.0.0.1 localhost
# 127.0.1.1 ubuntu-node

# # The following lines are desirable for IPv6 capable hosts
# ::1     ip6-localhost ip6-loopback
# fe00::0 ip6-localnet
# ff00::0 ip6-mcastprefix
# ff02::1 ip6-allnodes
# ff02::2 ip6-allrouters
# 192.168.10.150   controlplane
# 192.168.10.150   controlplane
```

---

## SA: disable token

- task

1. modify the config file in `/opt/cks/sa/pod-one.yaml` to disable the mounting of the sa token into the pod
2. apply updated manifests to ns one.
3. confirm sa token is not mounted.

- setup env

```sh
mkdir -p /opt/cks/sa
k create ns one
k create sa custom -n one

sudo tee /opt/cks/sa/pod-one.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-one
  namespace: one
spec:
  serviceAccountName: custom
  containers:
  - name: webserver
    image: nginx:latest
    ports:
    - containerPort: 80
EOF

k apply -f /opt/cks/sa/pod-one.yaml
```

---

- solution

```sh
cat /opt/cks/sa/pod-one.yaml

sudo vi /opt/cks/sa/pod-one.yaml
# spec:
#   serviceAccountName: custom
#   automountServiceAccountToken: false

kubectl replace --force -f /opt/cks/sa/pod-one.yaml
# confirm
kubectl exec -it pod/pod-one -n one -- ls /var/run/secrets/kubernetes.io/serviceaccount
# ls: cannot access '/var/run/secrets/kubernetes.io/serviceaccount': No such file or directory
```

---

## SA: mount token expire(killer A)

- task:
  - Update file `/course/4/stream-multiplex.yaml` with the following changes:
    - Pods should have annotation `token-lifetime` with value `1200` (annotation is informational only)
    - ServiceAccount `stream-multiplex` should be used (don't use deprecated fields)
    - Disable **automounting** of ServiceAccount tokens
    - The ServiceAccount token should be mounted at `/var/run/secrets/custom/` with an expiration of `1200s`
  - Apply the Deployment and ensure it's running without errors.

- setup env:

```yaml
# /course/4/stream-multiplex.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stream-multiplex
  namespace: team-coral
spec:
  replicas: 2
  selector:
    matchLabels:
      id: stream-multiplex
  template:
    metadata:
      labels:
        id: stream-multiplex
    spec :
      containers:
        - image: httpd: 2-alpine
          name: httpd
          resources:
            requests:
              cpu: 20m
              memory: 20Mi
```

---

- solution

```yaml
# /course/4/stream-multiplex.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stream-multiplex
  namespace: team-coral
spec:
  replicas: 2
  selector:
    matchLabels:
      id: stream-multiplex
  template:
    metadata:
      labels:
        id: stream-multiplex
      annotations:
        token-lifetime: "1200"
    spec:
      serviceAccountName: stream-multiplex
      automountServiceAccountToken: false
      containers:
        - name: httpd
          image: httpd:2-alpine
          resources:
            requests:
              cpu: 20m
              memory: 20Mi
          volumeMounts:
            - name: custom-token
              mountPath: /var/run/secrets/custom/
              readOnly: true
      volumes:
        - name: custom-token
          projected:
            sources:
              - serviceAccountToken:
                  path: token
                  expirationSeconds: 1200
```

```sh
# deploy
kubectl apply -f /course/4/stream-multiplex.yaml
kubectl get pods -n team-coral -l id=stream-multiplex

# confirm
kubectl exec -n team-coral deploy/stream-multiplex -- ls -l /var/run/secrets/custom/
```

> ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#manually-create-a-long-lived-api-token-for-a-serviceaccount
