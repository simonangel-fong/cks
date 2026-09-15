# Practices - Cilium

[Back](../README.md)

- [Practices - Cilium](#practices---cilium)
  - [Cilium NP](#cilium-np)

---

## Cilium NP

- context:
  - app-backend is deployed in backend ns
  - app-frontend is deployed in frontend ns
  - cilium is installed
- task:
  - create cilium network policy name `prod-netpol`
    - allow only app-frontend in frontend ns to access app-backnd in backend ns

---

- setup env:

```sh
# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend

# Deploy backend
kubectl create deployment app-backend --namespace=backend --image=nginx:alpine

kubectl expose deployment app-backend --namespace=backend --port=80 --target-port=80

# Deploy authorized frontend client
kubectl create deployment app-frontend --namespace=frontend --image=alpine/curl -- sleep 3600
```

---

- solution

```sh
# get label
kubectl get deploy --show-labels -n backend
# NAME          READY   UP-TO-DATE   AVAILABLE   AGE   LABELS
# app-backend   1/1     1            0           10s   app=app-backend

kubectl get deploy --show-labels -n frontend
# NAME           READY   UP-TO-DATE   AVAILABLE   AGE     LABELS
# app-frontend   1/1     1            1           5m48s   app=app-frontend
```

- create netpol

```yaml
# vi prod-netpol.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: prod-netpol
  namespace: backend
spec:
  endpointSelector:
    matchLabels:
      app: app-backend

  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: frontend
            app: app-frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

```sh
k apply -f prod-netpol.yaml
# ciliumnetworkpolicy.cilium.io/prod-netpol created

k get cnp -n backend
# NAME          AGE   VALID
# prod-netpol   23s   True

# test
kubectl exec -n frontend deployment/app-frontend -- curl -Is --connect-timeout 3 app-backend.backend.svc.cluster.local
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Tue, 15 Sep 2026 16:25:23 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 17:23:39 GMT
# Connection: keep-alive
# ETag: "6a985b9b-380"
# Accept-Ranges: bytes

# unauthorized pod
kubectl run client --image=alpine/curl --command -- sleep 3600
kubectl exec client -- curl -Is --connect-timeout 3 app-backend.backend.svc.cluster.local
# command terminated with exit code 28
```
