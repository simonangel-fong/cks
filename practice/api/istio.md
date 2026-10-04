# Practices - Istio

[Back](../../README.md)

- [Practices - Istio](#practices---istio)
  - [Shortcut](#shortcut)
  - [Istio: inject sidecar](#istio-inject-sidecar)
  - [Istio: enable namespace mTLS](#istio-enable-namespace-mtls)
  - [Istio: enable global mTLS](#istio-enable-global-mtls)
  - [Istio: enable mTLS (killer B)](#istio-enable-mtls-killer-b)
  - [Task: istio - sidecar, mtls](#task-istio---sidecar-mtls)

---

## Shortcut

| cmd                           | desccription              |
| ----------------------------- | ------------------------- |
| `istioctl analyze -n ns_name` | analyze a ns istio config |
| `istioctl analyze yaml_file`  | analyze a config file     |
| `istioctl analyze dir_name`   | analyze a dir             |

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

---

## Istio: enable mTLS (killer B)

- task:
  - Deployment one runs in Namespace `team-sedum` and communicates with Deployment `two` via a Service of the same name.
  - Istio has been installed in the cluster. Enable Istio sidecar injection for the whole Namespace and ensure all current and future Pods are running with the Istio proxy sidecar.

---

- solution:

```sh
# enable sidecar injection
k label ns team-sedum istio-injection=enabled
# confirm
k get ns team-sedum --show-labels

# sidecar inject
k -n team-sedum rollout restart deploy one
k -n team-sedum rollout restart deploy two

k -n team-sedum rollout get pod
```

---

## Task: istio - sidecar, mtls

Task
The namespace `encrypted` has two applications, `alpha` and `beta`.

Since these applications handle critical communications, enforce strict `mTLS` using Istio in the `encrypted` namespace.

Make sure that the workloads have the istio sidecar injected.

Note: istio and istioctl have already been installed for you.

---

- Solution

```sh
kubectl label namespace encrypted istio-injection=enabled --overwrite

kubectl -n encrypted rollout restart deployment alpha beta
kubectl -n encrypted rollout status deployment alpha
kubectl -n encrypted rollout status deployment beta
```

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: encrypted
spec:
  mtls:
    mode: STRICT
```

---
