# Practices - Istio

[Back](../../README.md)

- [Practices - Istio](#practices---istio)
  - [Istio: inject sidecar](#istio-inject-sidecar)
  - [Istio: enable namespace mTLS](#istio-enable-namespace-mtls)
  - [Istio: enable global mTLS](#istio-enable-global-mtls)

---

- Istio
  - sidecar inject: https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/#deploying-an-app
  - peer authentication: https://istio.io/latest/docs/reference/config/security/peer_authentication/

## Istio: inject sidecar

- task:
  - deploy `backend` is running in `sidecar` ns
  - enable sidecar injection for ns `sidecar`
  - update `backend` and confirm sidecars are injected.

- setup env:

```sh
k create ns sidecar
kubectl create deploy backend --image=nginx --replicas=2 -n sidecar
```

---

- solution

```sh
k get po -n sidecar
# NAME                       READY   STATUS    RESTARTS   AGE
# backend-7795987bc5-7ksfz   1/1     Running   0          12s
# backend-7795987bc5-b9z9b   1/1     Running   0          12s

# sidecar injection
k label ns sidecar istio-injection=enabled

k rollout restart deploy backend -n sidecar

# confirm
k get po -n sidecar -w
# NAME                       READY   STATUS    RESTARTS   AGE
# backend-64955c65cb-4cmx8   2/2     Running   0          60s
# backend-64955c65cb-94c5h   2/2     Running   0          54s
```

---

## Istio: enable namespace mTLS

- task
  - deploy `backend` is running in `sidecar` ns
  - enable namespace-wide mtls `STRICT` mode

---

- solution

```yaml
# backend-pa.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: backend
  namespace: sidecar
spec:
  mtls:
    mode: STRICT
```

```sh
k apply -f backend-pa.yaml

k get pa -n sidecar
# NAME      MODE     AGE
# backend   STRICT   41s
```

---

## Istio: enable global mTLS

- task:
  - enable mTLS `STRICT` mode for cluster

---

- solution:

```yaml
# global-pa.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: "global"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
```

```sh
k apply -f global-pa.yaml

# confirm
k get pa -n istio-system
# NAME     MODE     AGE
# global   STRICT   6s
```
