# CKS: Cilium - Deny Policies

[Back](../README.md)

- [CKS: Cilium - Deny Policies](#cks-cilium---deny-policies)
  - [Deny Policies](#deny-policies)
  - [Lab: Deny policies](#lab-deny-policies)
    - [Setup](#setup)
    - [ingressDeny](#ingressdeny)
    - [egressDeny](#egressdeny)

---

## Deny Policies

- `Deny Policies`
  - allow to **explicitly block** certain network traffic between pods in a Kubernetes cluster.
- `Deny policies` take **precedence over** `allow policies`
  - if **both** an allow and deny policy exist, the `deny policy` will **win**.

- `ingressDeny`
  - **Blocks** specific **incoming** traffic, even if other policies would allow it
- `egressDeny`
  - **Blocks** specific **outgoing** traffic, even if other policies would allow it

---

## Lab: Deny policies

### Setup

```sh
# create app-target
kubectl run app-target --image=nginx --labels=app=target
# pod/app-target created

# create curl-random
kubectl run curl-random --image=alpine/curl --labels=app=random -- sleep 3600
# pod/curl-random created

# create curl-test
kubectl run curl-test --image=alpine/curl --labels=app=test -- sleep 3600
# pod/curl-test created

kubectl get pods -o wide
# NAME          READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE   READINESS GATES
# app-target    1/1     Running   0          6m36s   10.0.1.33    node01   <none>           <none>
# curl-random   1/1     Running   0          10s     10.0.1.224   node01   <none>           <none>
# curl-test     1/1     Running   0          6m36s   10.0.1.143   node01   <none>           <none>
```

---

### ingressDeny

```sh
cat << EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-ingress"
spec:
  endpointSelector:
    matchLabels:
      app: target
  ingress:
  - fromEntities:
    - all
  ingressDeny:
  - fromEndpoints:
    - matchLabels:
        app: random
EOF
# ciliumnetworkpolicy.cilium.io/deny-ingress created

# confirm: test -> app, succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.33
# PING 10.0.1.33 (10.0.1.33): 56 data bytes
# 64 bytes from 10.0.1.33: seq=0 ttl=63 time=4.709 ms
# 64 bytes from 10.0.1.33: seq=1 ttl=63 time=0.068 ms

# --- 10.0.1.33 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.068/2.388/4.709 ms

# confirm: random -> app, block
kubectl exec -it curl-random -- ping -c2 10.0.1.33
# PING 10.0.1.33 (10.0.1.33): 56 data bytes

# --- 10.0.1.33 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# clean up
kubectl delete cnp deny-ingress
# ciliumnetworkpolicy.cilium.io "deny-ingress" deleted
```

---

### egressDeny

```sh
cat << EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-egress"
spec:
  endpointSelector:
    matchLabels:
      app: test
  egress:
  - toEntities:
    - all
  egressDeny:
  - toEndpoints:
    - matchLabels:
        app: random
EOF
# ciliumnetworkpolicy.cilium.io/deny-egress created

# confirm: test -> app, succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.33
# PING 10.0.1.33 (10.0.1.33): 56 data bytes
# 64 bytes from 10.0.1.33: seq=0 ttl=63 time=0.925 ms
# 64 bytes from 10.0.1.33: seq=1 ttl=63 time=0.120 ms

# --- 10.0.1.33 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.120/0.522/0.925 ms

# confirm: test -> random, block
kubectl exec -it curl-test -- ping -c2 10.0.1.224
# PING 10.0.1.224 (10.0.1.224): 56 data bytes

# --- 10.0.1.224 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# clean up
kubectl delete cnp deny-egress

kubectl delete po --all
```
