# CKS: Cilium Network Policies

[Back](../README.md)

- [CKS: Cilium Network Policies](#cks-cilium-network-policies)
  - [Cilium Network Policies](#cilium-network-policies)
    - [Declarative](#declarative)
  - [Lab: Cilium network policy](#lab-cilium-network-policy)
    - [Setup](#setup)
    - [Deny All](#deny-all)
    - [Deny a pod](#deny-a-pod)
    - [Allow ingress](#allow-ingress)
    - [Allow egress](#allow-egress)

---

## Cilium Network Policies

- `Cilium network policy`
  - provides more granularity, flexibility, and advanced features than the standard Kubernetes `network policy`.
- Cilium supports defining granular rulesets at **Layers 3, 4, and 7** of the OSI model

| Feature                      | K8s Network Policy | Cilium Network Policy |
| ---------------------------- | ------------------ | --------------------- |
| Basic L3/L4 layer isolations | Yes                | Yes                   |
| L7 (HTTP,DNS, Kafka)         | No                 | Yes                   |
| Better observability         | No                 | Yes (Hubble)          |

---

### Declarative

- Structure
  - `endpointSelector`: select which **endpoints (pods)** the policy applies to, based on their Kubernetes **labels**
  - `Ingress`:
    - defines rules for incoming traffic.
  - `Egress`:
    - defines rules for outgoing traffic.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "cnp_name"
spec:
  # endpoints/pods to apply cnp
  endpointSelector:
    matchLabels:
      # pod labels
  # ingress rules
  ingress:
    - ...
  # egress rules
  egress:
    - ...
```

---

## Lab: Cilium network policy

### Setup

```sh
# ##############################
# without
# ##############################
# target app pod
kubectl run app-target --image=nginx
# pod/app-target created

# test pod
kubectl run curl-test --image=alpine/curl -- sleep 3600
# pod/curl-test created

# alternative pod
kubectl run curl-alter --image=alpine/curl -- sleep 3600
# pod/curl-alter created

# confirm
kubectl get pods -o wide
# NAME         READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
# app-target   1/1     Running   0          38s   10.0.1.120   node01   <none>           <none>
# curl-alter   1/1     Running   0          9s    10.0.1.136   node01   <none>           <none>
# curl-test    1/1     Running   0          28s   10.0.1.178   node01   <none>           <none>

# confirm connectivity
kubectl exec -it curl-test -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes
# 64 bytes from 10.0.1.120: seq=0 ttl=63 time=2.604 ms
# 64 bytes from 10.0.1.120: seq=1 ttl=63 time=0.137 ms

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.137/1.370/2.604 ms

kubectl exec -it curl-alter -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes
# 64 bytes from 10.0.1.120: seq=0 ttl=63 time=26.438 ms
# 64 bytes from 10.0.1.120: seq=1 ttl=63 time=0.236 ms

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.236/13.337/26.438 ms
```

---

### Deny All

```sh
# ##############################
# Policy: Deny all
# ##############################
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-all"
spec:
  endpointSelector: {}
  ingress:
    - {}
  egress:
    - {}
EOF
# ciliumnetworkpolicy.cilium.io/deny-all created

# confirm
kubectl get cnp
# NAME       AGE   VALID
# deny-all   22s   True

kubectl describe cnp deny-all
# Name:         deny-all
# Namespace:    default
# Labels:       <none>
# Annotations:  <none>
# API Version:  cilium.io/v2
# Kind:         CiliumNetworkPolicy
# Metadata:
#   Creation Timestamp:  2026-09-09T19:00:18Z
#   Generation:          1
#   Resource Version:    29710
#   UID:                 fbfb1cc3-a847-4134-94fc-0b81b145e220
# Spec:
#   Egress:
#   Endpoint Selector:
#   Ingress:
# Status:
#   Conditions:
#     Last Transition Time:  2026-09-09T19:00:18Z
#     Message:               Policy validation succeeded
#     Status:                True
#     Type:                  Valid
# Events:                    <none>

# confirm connectivity: curl-test -> app-target
kubectl exec -it curl-test -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# confirm connectivity: curl-alter -> app-target
kubectl exec -it curl-alter -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# clean up
kubectl delete cnp deny-all
# ciliumnetworkpolicy.cilium.io "deny-all" deleted
```

---

### Deny a pod

```sh
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-curl-test-pod"
spec:
  endpointSelector:
    matchLabels:
      run: curl-test
  ingress:
    - {}
  egress:
    - {}
EOF
# ciliumnetworkpolicy.cilium.io/deny-curl-test-pod created

# confirm
kubectl get cnp
# NAME                 AGE   VALID
# deny-curl-test-pod   13s   True

# confirm connectivity: curl-test -> app-target
kubectl exec -it curl-test -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# confirm connectivity: curl-alter -> app-target
kubectl exec -it curl-alter -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes
# 64 bytes from 10.0.1.120: seq=0 ttl=63 time=0.211 ms
# 64 bytes from 10.0.1.120: seq=1 ttl=63 time=0.087 ms

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.087/0.149/0.211 ms

# clean up
kubectl delete cnp deny-curl-test-pod
# ciliumnetworkpolicy.cilium.io "deny-curl-test-pod" deleted
```

---

### Allow ingress

```sh
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-ingress-target-app
spec:
  endpointSelector:
    matchLabels:
      run: app-target
  ingress:
    - fromEndpoints:
        - matchLabels:
            run: curl-test
EOF
# ciliumnetworkpolicy.cilium.io/allow-ingress-target-app created

kubectl get cnp
# NAME                       AGE   VALID
# allow-ingress-target-app   11s   True

# confirm curl-test -> app-target: succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes
# 64 bytes from 10.0.1.120: seq=0 ttl=63 time=2.103 ms
# 64 bytes from 10.0.1.120: seq=1 ttl=63 time=0.083 ms

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.083/1.093/2.103 ms

# confirm curl-alter -> app-target: fail
kubectl exec -it curl-alter -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# clean up
kubectl delete cnp allow-ingress-target-app
# ciliumnetworkpolicy.cilium.io "allow-ingress-target-app" deleted
```

---

### Allow egress

```sh
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-egress-curl-test
spec:
  endpointSelector:
    matchLabels:
      run: curl-test
  egress:
    - toEndpoints:
        - matchLabels:
            run: app-target
EOF
# ciliumnetworkpolicy.cilium.io/allow-egress-curl-test created

kubectl get cnp
# NAME                     AGE   VALID
# allow-egress-curl-test   13s   True

# confirm curl-test -> app-target: succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.120
# PING 10.0.1.120 (10.0.1.120): 56 data bytes
# 64 bytes from 10.0.1.120: seq=0 ttl=63 time=2.054 ms
# 64 bytes from 10.0.1.120: seq=1 ttl=63 time=0.069 ms

# --- 10.0.1.120 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.069/1.061/2.054 ms

# confirm curl-test -> curl-alter: fail
kubectl exec -it curl-test -- ping -c2 10.0.1.136
# PING 10.0.1.136 (10.0.1.136): 56 data bytes

# --- 10.0.1.136 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# confirm curl-alter -> curl-test: succeed
kubectl exec -it curl-alter -- ping -c2 10.0.1.178
# PING 10.0.1.178 (10.0.1.178): 56 data bytes
# 64 bytes from 10.0.1.178: seq=0 ttl=63 time=1.222 ms
# 64 bytes from 10.0.1.178: seq=1 ttl=63 time=0.104 ms

# --- 10.0.1.178 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.104/0.663/1.222 ms

# clean up
kubectl delete cnp allow-egress-curl-test
# ciliumnetworkpolicy.cilium.io "allow-egress-curl-test" deleted

kubectl delete pod --all
```

---
