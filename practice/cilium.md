# Practices - Cilium

[Back](../README.md)

- [Practices - Cilium](#practices---cilium)
  - [Cilium NP](#cilium-np)
  - [Entity](#entity)

---

- Network Policies + Cilium Network Policies
  - For Cilium Network Policy:
    - Be aware of `ingressDeny` and `egressDeny` block.
    - Be aware of the `Entities` in Cilium Network Policies.

## Cilium NP

- context:
  - `app-backend` is deployed in `backend` ns
  - `app-frontend` is deployed in `frontend` ns
  - cilium is installed
- task:
  - create cilium network policy name `frontend`
    - allow only app in `backend` ns to access app in `frontend` ns

---

- setup env:

```sh
# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend

# Deploy backend
kubectl create deployment backend -n backend --image=nginx:alpine

# Deploy frontend
kubectl create deployment frontend -n frontend --image=nginx:alpine

```

---

- solution

```sh
kubectl get po -n frontend -o wide --show-labels
# NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES   LABELS
# frontend-7d46867bb4-xq7wp   1/1     Running   0          9s    10.0.1.137   node01   <none>           <none>            app=frontend,pod-template-hash=7d46867bb4

kubectl get po -n backend -o wide --show-labels
# NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES   LABELS
# backend-66bb89cb8d-fq4jk   1/1     Running   0          27s   10.0.1.169   node01   <none>           <none>            app=backend,pod-template-hash=66bb89cb8d
```

- create netpol

```yaml
# vi frontend
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: frontend
  namespace: frontend
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  ingress:
    - fromEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": backend
            app: backend
```

```sh
k apply -f frontend.yaml
# ciliumnetworkpolicy.cilium.io/frontend created

k get cnp -n frontend
# NAMESPACE   NAME       AGE   VALID
# frontend    frontend   17s   True

# test
kubectl -n backend exec backend-66bb89cb8d-fq4jk -- curl 10.0.1.137

# test in default
kubectl run test --image=alpine/curl --command -- sleep 1h
k exec test -- ping -c2 10.0.1.137
# PING 10.0.1.137 (10.0.1.137): 56 data bytes

# --- 10.0.1.137 ping statistics ---
# 2 packets transmitted, 0 packets received, 100% packet loss
# command terminated with exit code 1
```

---

```yaml
# select specific label
endpointSelector:
  matchLabels:
    app: frontend

# select all
endpointSelector:
  matchLabels: {}

# namespace
- fromEndpoints:
  - matchLabels:
    "k8s:io.kubernetes.pod.namespace": backend
    app: backend

```

## Entity
