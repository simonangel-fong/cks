# Practices - Network policy

[Back](../../README.md)

- [Practices - Network policy](#practices---network-policy)
  - [ref](#ref)
  - [NP: deny all](#np-deny-all)
  - [NP: ip block](#np-ip-block)
  - [NP: net pol](#np-net-pol)

---

## ref

- keyword: network policy
- ref: https://kubernetes.io/docs/concepts/services-networking/network-policies/

## NP: deny all

- task
  - an existing deployment is running in default ns
  - create a network policy `deny-all` to secure the deployment by deny both ingress and engress.
- setup

```sh
kubectl create deploy app --image=nginx --replicas=2
kubectl expose deploy app --port=80 --target-port=80
```

- solution

```yaml
# vi np.yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

```sh
k apply -f np.yaml

k get po -o wide
# NAME                   READY   STATUS    RESTARTS   AGE    IP               NODE           NOMINATED NODE   READINESS GATES
# app-6b97cd8cbd-rjnrc   1/1     Running   0          3m8s   10.244.196.130   node01         <none>           <none>
# app-6b97cd8cbd-z4vzd   1/1     Running   0          3m8s   10.244.49.119    controlplane   <none>           <none>

k run test --image=busybox --command -- sleep 3600
k exec -it test -- curl 10.244.196.130
k exec -it test -- curl app.default.svc.cluster.local

```

---

## NP: ip block

- task
  - create np name np-ip that allows outbound traffic to any ip `0.0.0.0/0` but block ip `192.168.10.150/32`

---

- solution

```yaml
# vi np-ip.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-ip
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 192.168.10.150/32
```

```sh
k apply -f np-ip.yaml

k run test --image=alpine/curl --command -- sleep 3600
k exec -it test -- sh
ping -c2 8.8.8.8
ping -c2 1.1.1.1
ping -c2 192.168.10.150 # block
```

---

## NP: net pol

- task
  - create `beta` ns, create deployment in `beta` ns with name `beta-web` and iamge `nginx:latest`, replicas =2, container name = `web`, container port = `80`
  - enforcing apparmor profile `secure-nginx` on web container
  - expose deploy via svc named `beta-web-svc` of clusterIP
    - port 80, target port 80
  - create net pol named `allow-frontend-only` in `beta` ns
    - allow incoming traffic to deploy `beta-web` only from the pod `frontend`(same ns)
    - deny all incomming traffic to deploy `beta-web`
    - pod `frontend` labels: `role: frontend`

---

- setup env: both master

```sh
sudo tee /etc/apparmor.d/secure-nginx > /dev/null <<'EOF'
#include <tunables/global>

profile secure-nginx flags=(attach_disconnected) {
  #include <abstractions/base>

  # allow everything by default, then deny a couple of things
  file,
  network,
  capability,
  umount,

  # the actual "security" bit for the lab
  deny /etc/shadow rwklx,
  deny /bin/dash rwklx,
  deny /bin/sh   rwklx,
  deny /usr/bin/top rwklx,
}
EOF
# enforce
sudo apparmor_parser -r -W /etc/apparmor.d/secure-nginx
# confirm
sudo aa-status | grep secure-nginx
```

---

- solution

```sh
k create ns beta
kubectl -n beta create deployment beta-web --image=nginx:latest --replicas=2 --port=80 --dry-run=client -o yaml > beta-web.yaml

nano  beta-web.yaml
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   labels:
#     app: beta-web
#   name: beta-web
#   namespace: beta
# spec:
#   replicas: 2
#   selector:
#     matchLabels:
#       app: beta-web
#   strategy: {}
#   template:
#     metadata:
#       labels:
#         app: beta-web
#     spec:
#       securityContext:
#         appArmorProfile:
#           type: Localhost
#           localhostProfile: secure-nginx
#       containers:
#       - image: nginx:latest
#         name: web
#         ports:
#         - containerPort: 80
#         resources: {}
# status: {}

k apply -f beta-web.yaml

# confirm
k describe deploy beta-web -n beta
k get po -n beta
# NAME                        READY   STATUS        RESTARTS   AGE     LABELS
# beta-web-64cbdfd549-ddsdc   1/1     Running       0          7m11s   app=beta-web,pod-template-hash=64cbdfd549
# beta-web-64cbdfd549-x4krx   1/1     Running       0          7m11s   app=beta-web,pod-template-hash=64cbdfd549

k expose deploy beta-web -n beta --name=beta-web-svc --port=80 --target-port=80
# service/beta-web-svc exposed
# service/beta-web exposed

k describe svc service/beta-web-svc -n beta
# Name:                     beta-web-svc
# Namespace:                beta
# Labels:                   app=beta-web
# Annotations:              <none>
# Selector:                 app=beta-web
# Type:                     ClusterIP
# IP Family Policy:         SingleStack
# IP Families:              IPv4
# IP:                       10.103.108.52
# IPs:                      10.103.108.52
# Port:                     <unset>  80/TCP
# TargetPort:               80/TCP
# Endpoints:                10.244.196.139:80,10.244.49.127:80
# Session Affinity:         None
# Internal Traffic Policy:  Cluster
# Events:                   <none>
```

- net pol

```yaml
# vi net_pol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-only
  namespace: beta
spec:
  podSelector:
    matchLabels:
      app: beta-web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

```sh
k apply -f net_pol.yaml

k describe netpol -n beta
# Name:         allow-frontend-only
# Namespace:    beta
# Created on:   2026-09-14 15:42:42 -0400 EDT
# Labels:       <none>
# Annotations:  <none>
# Spec:
#   PodSelector:     app=beta-web
#   Allowing ingress traffic:
#     To Port: 80/TCP
#     From:
#       PodSelector: role=frontend
#   Not affecting egress traffic
#   Policy Types: Ingress
```

---

| Command                                     | Description                                                                        |
| ------------------------------------------- | ---------------------------------------------------------------------------------- |
| cat /sys/module/apparmor/parameters/enabled | Checks if AppArmor is enabled in the Linux kernel (should return Y).               |
| sudo aa-status                              | Shows the current status of AppArmor, listing all loaded profiles and their modes. |
| sudo apparmor_parser /path/to/profile       | Loads a new AppArmor profile file into the kernel memory.                          |
| sudo apparmor_parser -r /path/to/profile    | Replaces or reloads an existing profile (critical if you updated a file).          |
| sudo aa-enforce /path/to/profile            | Changes a loaded profile's mode to Enforce, strictly blocking disallowed actions.  |
