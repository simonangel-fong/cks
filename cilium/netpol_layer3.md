# CKS: Cilium - Layer 3 Policies

[Back](../README.md)

- [CKS: Cilium - Layer 3 Policies](#cks-cilium---layer-3-policies)
  - [Layer 3 Policies](#layer-3-policies)
  - [Entities Based policy](#entities-based-policy)
    - [Lab: entities](#lab-entities)
      - [Setup](#setup)
      - [Cluster entity](#cluster-entity)
      - [World entity](#world-entity)
      - [All entity](#all-entity)

---

## Layer 3 Policies

- `layer 3 policy` establishes the **base connectivity rules** regarding which endpoints can talk to each other.
- methods:

| Types           | Description                                                                            |
| --------------- | -------------------------------------------------------------------------------------- |
| Endpoints Based | Based on Kubernetes **pod labels**, allowing or denying traffic between specific pods. |
| Services based  | based on Kubernetes **services**, controlling traffic based on **service names**       |
| Node based      | based on the **nodes** in the cluster                                                  |
| IP/CIDR based   | based on specific **IP** addresses or **CIDR blocks**                                  |
| Entities Based  | **predefined entity groups** like "cluster", "host", "world", or "all".                |

---

## Entities Based policy

- To define network policies, Cilium provides **predefined entities**:

| Entities    | Description                                                                                                          |
| ----------- | -------------------------------------------------------------------------------------------------------------------- |
| world       | Represents **any external** (non-cluster) traffic, including the **internet**.                                       |
| host        | Represents the local Kubernetes **node** (host network)                                                              |
| remote-node | Represents **other Kubernetes nodes** in the cluster that are **not the local node**.                                |
| cluster     | Represents **all** workload endpoints **within** the Kubernetes cluster. Includes **all pods across all namespaces** |
| all         | Represents **all** possible **endpoints** both **inside and outside** the cluster.                                   |

---

### Lab: entities

#### Setup

```sh
# create app-target
kubectl run app-target --image=nginx
# pod/app-target created

# create curl-test
kubectl run curl-test --image=alpine/curl -- sleep 3600
# pod/curl-test created

# confirm
kubectl get po -o wide
# NAME         READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE   READINESS GATES
# app-target   1/1     Running   0          2m31s   10.0.1.65    node01   <none>           <none>
# curl-test    1/1     Running   0          2m22s   10.0.1.139   node01   <none>           <none>

# confirm: incluster
kubectl exec -it curl-test -- ping -c2 10.0.1.65
# PING 10.0.1.65 (10.0.1.65): 56 data bytes
# 64 bytes from 10.0.1.65: seq=0 ttl=63 time=5.095 ms
# 64 bytes from 10.0.1.65: seq=1 ttl=63 time=0.149 ms

# --- 10.0.1.65 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.149/2.622/5.095 ms

# confirm: external
kubectl exec -it curl-test -- ping -c2 8.8.8.8
# PING 8.8.8.8 (8.8.8.8): 56 data bytes
# 64 bytes from 8.8.8.8: seq=0 ttl=126 time=36.707 ms
# 64 bytes from 8.8.8.8: seq=1 ttl=126 time=18.279 ms

# --- 8.8.8.8 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 18.279/27.493/36.707 ms
```

---

#### Cluster entity

```sh
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "restrict-egress-to-cluster"
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - "cluster"
EOF
# ciliumnetworkpolicy.cilium.io/restrict-egress-to-cluster created

# confirm incluster: succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.65
# PING 10.0.1.65 (10.0.1.65): 56 data bytes
# 64 bytes from 10.0.1.65: seq=0 ttl=63 time=0.475 ms
# 64 bytes from 10.0.1.65: seq=1 ttl=63 time=0.187 ms

# --- 10.0.1.65 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.187/0.331/0.475 ms

# confirm: external
kubectl exec -it curl-test -- ping -c2 8.8.8.8
# PING 8.8.8.8 (8.8.8.8): 56 data bytes

# --- 8.8.8.8 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# clean up
kubectl delete cnp restrict-egress-to-cluster
# ciliumnetworkpolicy.cilium.io "restrict-egress-to-cluster" deleted
```

---

#### World entity

```sh
cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "restrict-egress-to-world"
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - "world"
EOF
# ciliumnetworkpolicy.cilium.io/restrict-egress-to-world created

# confirm incluster: succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.65
# PING 10.0.1.65 (10.0.1.65): 56 data bytes

# --- 10.0.1.65 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1

# confirm: external
kubectl exec -it curl-test -- ping -c2 8.8.8.8
# PING 8.8.8.8 (8.8.8.8): 56 data bytes
# 64 bytes from 8.8.8.8: seq=0 ttl=126 time=43.186 ms
# 64 bytes from 8.8.8.8: seq=1 ttl=126 time=41.786 ms

# --- 8.8.8.8 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 41.786/42.486/43.186 ms

# clean up
kubectl delete cnp restrict-egress-to-world
# ciliumnetworkpolicy.cilium.io "restrict-egress-to-world" deleted
```

---

#### All entity

```sh
cat << EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-all-egress"
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - "all"
EOF
# ciliumnetworkpolicy.cilium.io/allow-all-egress created

# confirm incluster: succeed
kubectl exec -it curl-test -- ping -c2 10.0.1.65
# PING 10.0.1.65 (10.0.1.65): 56 data bytes
# 64 bytes from 10.0.1.65: seq=0 ttl=63 time=0.616 ms
# 64 bytes from 10.0.1.65: seq=1 ttl=63 time=0.121 ms

# --- 10.0.1.65 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.121/0.368/0.616 ms

# confirm: external
kubectl exec -it curl-test -- ping -c2 8.8.8.8
# PING 8.8.8.8 (8.8.8.8): 56 data bytes
# 64 bytes from 8.8.8.8: seq=0 ttl=126 time=77.040 ms
# 64 bytes from 8.8.8.8: seq=1 ttl=126 time=24.556 ms

# --- 8.8.8.8 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 24.556/50.798/77.040 ms

# clean up
kubectl delete cnp allow-all-egress
# ciliumnetworkpolicy.cilium.io "allow-all-egress" deleted
```
