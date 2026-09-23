# Practices - Cilium

[Back](../../README.md)

- [Practices - Cilium](#practices---cilium)
  - [Shortcut](#shortcut)
  - [Cilium NP](#cilium-np)
  - [Cilium(killer A)](#ciliumkiller-a)
  - [CNP(kill B)](#cnpkill-b)

---

## Shortcut

- Network Policies + Cilium Network Policies
  - For Cilium Network Policy:
    - Be aware of `ingressDeny` and `egressDeny` block.
    - Be aware of the `Entities` in Cilium Network Policies.

- common config

```yaml
# select specific label
endpointSelector:
  matchLabels:
    app: frontend

# select all
endpointSelector:
  matchLabels: {}

# all in namespace
- fromEndpoints:
  - matchLabels:
    "k8s:io.kubernetes.pod.namespace": backend # ns

# endpoint in ns
- fromEndpoints:
  - matchLabels:
    "k8s:io.kubernetes.pod.namespace": backend # ns
    app: backend # endpoint

# enable mtls
- toEndpoints:
    - matchLabels:
        type: messenger
  authentication:
    mode: "required" # Enable Mutual Authentication

```

---

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
# entity
# Allow egress to 0.0.0.0/0
- toEntities:
    - world

# select specific label
endpointSelector:
  matchLabels:
    app: frontend

# select all
endpointSelector:
  matchLabels: {}

# all in namespace
- fromEndpoints:
  - matchLabels:
    "k8s:io.kubernetes.pod.namespace": backend

# endpoint in ns
- fromEndpoints:
  - matchLabels:
    "k8s:io.kubernetes.pod.namespace": backend
    app: backend

# deny icmp
egressDeny:
  - toEndpoints:
      - matchLabels:
          type: database
    icmps:
      - fields:
          - type: 8
            family: IPv4
          - type: EchoRequest
            family: IPv6

```

## Cilium(killer A)

- task:
  - There is a metadata service available at `http://192.168.100.21:9055` through which nodes can access sensitive data. Access to this needs to be restricted from Pods.
  - In Namespace `metadata-access` create a CiliumNetworkPolicy named `default` to:
    - Allow egress to 0.0.0.0/0
    - Allow egress to Endpoints in the same Namespace
    - Allow egress to Endpoints in the kube-system Namespace (this covers DNS resolution)
    - Deny egress to 192.168.100.21 on port 9055
  - ℹ️ There are existing plain Nginx Pods with open port 80 in the Namespace which can be used for testing but need to remain unchanged. - Perform simple connectivity tests like:
  - `k -n metadata-access exec POD_NAME -- curl URL`

---

- solution:

```yaml
# cnp.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default
  namespace: metadata-access
spec:
  endpointSelector: {}

  egress:
    # Allow egress to 0.0.0.0/0
    - toEntities:
        - world
    # Allow egress to Endpoints in the same Namespace
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: metadata-access
    # Allow egress to Endpoints in the kube-system Namespace
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
  # Deny egress to 192.168.100.21 on port 9055
  egressDeny:
  - toCIDR:
    - 192.168.100.21/32
      toPorts:
        - ports:
            - port: "9055"
```

---

## CNP(kill B)

- task:
  - In Namespace `team-iris` a Default-Allow strategy for all Namespace-internal traffic was chosen. There is an existing CiliumNetworkPolicy `default-allow` which ensures this and which should not be altered. That policy also allows cluster-internal DNS resolution.
  - Now it's time to deny and authenticate certain traffic. Create 3 CiliumNetworkPolicies in Namespace `team-iris` to implement the following requirements:
    - Create a Layer 3 policy named `p1` to:
      - Deny outgoing traffic from Pods with label `type=messenger` to Pods with label `type=database`
    - Create a Layer 4 policy named `p2` to:
      - Deny outgoing `ICMP EchoRequest` traffic from Deployment `transmitter` to Pods with label `type=database`
    - Create a Layer 3 policy named `p3` to:
      - Enable Mutual Authentication for outgoing traffic from Pods with label `type=database` to Pods with label `type=messenger`

---

- solution:
- p1

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: p1
  namespace: team-iris
spec:
  endpointSelector:
    matchLabels:
      type: messenger
  egressDeny:
    - toEndpoints:
        - matchLabels:
            type: database # we use the label of the Pods behind the Service "database"
```

- p2

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: p2
  namespace: team-iris
spec:
  endpointSelector:
    matchLabels:
      type: transmitter
  egressDeny:
    - toEndpoints:
        - matchLabels:
            type: database
      icmps:
        - fields:
            - type: 8
              family: IPv4
            - type: EchoRequest
              family: IPv6
```

- p3

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: p3
  namespace: team-iris
spec:
  endpointSelector:
    matchLabels:
      type: database
  egress:
    - toEndpoints:
        - matchLabels:
            type: messenger
      authentication:
        mode: "required" # Enable Mutual Authentication
```
