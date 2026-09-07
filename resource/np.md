# CKS: Network policies

[Back](../README.md)

- [CKS: Network policies](#cks-network-policies)
  - [Network policies](#network-policies)
    - [Supported Filtering Entities](#supported-filtering-entities)
    - [except field](#except-field)
    - [Ports and Protocol](#ports-and-protocol)
  - [Lab: network policy](#lab-network-policy)
    - [flat network](#flat-network)
    - [Deny all](#deny-all)

---

## Network policies

- By default, Kubernetes uses a **flat network model**
  - every `pod` gets a unique **IP address** and can **talk to any other** `pod` across any node without network address translation (NAT).
- `Network Policies`
  - controls network traffic flow in

- Types of Rules
  - Ingress Rules (Inbound Rule)
  - Egress Rules (Outbound Rule)

---

### Supported Filtering Entities

- The **entities** that a Pod can communicate with are **identified** through a combination of the following three **identifiers**:
  - `podSelector`: filtered by pod labels
  - `namespaceSelector`
  - `ipBlock`

- `podSelector: {}`: select all

---

### except field

- used to define exceptions to a broader rule.
- sample

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - ipBlock:
            cidr: 172.17.0.0/16
            except:
              - 172.17.1.0/24
```

---

### Ports and Protocol

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-port-egress
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/24
      ports:
        - protocol: TCP
          port: 32000 # Targeting a range of ports
          endPort: 32768
```

---

## Lab: network policy

### flat network

```sh
# deploy app pod
kubectl run app --image=nginx
# pod/app created

# deploy test pod
kubectl run curl-test --image=alpine/curl -- sleep 3600
# pod/curl-test created

kubectl get pod app -o wide
# NAME   READY   STATUS    RESTARTS   AGE     IP               NODE     NOMINATED NODE   READINESS GATES
# app    1/1     Running   0          2m31s   10.244.196.140   node01   <none>           <none>

kubectl exec curl-test -- ping -c3 10.244.196.140
# PING 10.244.196.140 (10.244.196.140): 56 data bytes
# 64 bytes from 10.244.196.140: seq=0 ttl=63 time=2.239 ms
# 64 bytes from 10.244.196.140: seq=1 ttl=63 time=0.096 ms
# 64 bytes from 10.244.196.140: seq=2 ttl=63 time=0.096 ms

# --- 10.244.196.140 ping statistics ---
# 3 packets transmitted, 3 packets received, 0% packet loss
# round-trip min/avg/max = 0.096/0.810/2.239 ms

kubectl exec curl-test -- curl -I http://10.244.196.140
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Mon, 07 Sep 2026 02:50:54 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

```

---

### Deny all

```sh
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
# networkpolicy.networking.k8s.io/deny-all created

kubectl get netpol
# NAME       POD-SELECTOR   AGE
# deny-all   <none>         11s

kubectl describe netpol
# Name:         deny-all
# Namespace:    default
# Created on:   2026-09-06 22:51:50 -0400 EDT
# Labels:       <none>
# Annotations:  <none>
# Spec:
#   PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
#   Allowing ingress traffic:
#     <none> (Selected pods are isolated for ingress connectivity)
#   Allowing egress traffic:
#     <none> (Selected pods are isolated for egress connectivity)
#   Policy Types: Ingress, Egress

kubectl exec curl-test -- ping -c3 10.244.196.140
# PING 10.244.196.140 (10.244.196.140): 56 data bytes

# --- 10.244.196.140 ping statistics ---
# 3 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

kubectl delete netpol deny-all
# networkpolicy.networking.k8s.io "deny-all" deleted from default namespace


```

---
