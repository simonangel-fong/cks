# CKS: Istio - mTLS

[Back](../README.md)

- [CKS: Istio - mTLS](#cks-istio---mtls)
  - [`Peer Authentication`](#peer-authentication)
    - [Declarative](#declarative)
  - [Lab: mTLS](#lab-mtls)

---

## `Peer Authentication`

- `mTLS`
  - `Istiod` can act as a `Certificate Authority (CA)` and generates certificates to allow secure `mTLS` communication in the `data plane`.

- `Peer Authentication`
  - a custom resource used to **define** `mutual TLS (mTLS)` requirements for **service-to-service communication.**

- **Scope Levels**
  - `Mesh-wide`:
    - Applied in the **root namespace** (like istio-system) to affect the **entire mesh**.
  - `Namespace-wide`:
    - Applied to a **specific namespace**.
  - `Workload-specific`:
    - Uses selectors to target individual **pods** or specific **ports**.
    - key `spec.selector`:determines the workloads to apply
    - key `spec.portLevelMtls`: Port specific mutual TLS settings.

- `mTLS` Modes
  - key `mtls.mode`
  - `STRICT`:
    - **Only accepts** mTLS traffic;
    - **plain text** connections are **rejected**.
  - `PERMISSIVE`:
    - default mode
    - Accepts **both** mTLS and plain text connections
  - `DISABLE`:
    - **Turns off** mTLS entirely.
  - `UNSET`:
    - **Inherits** the mode from the **parent scope**.

---

### Declarative

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: foo # ns scope
spec:
  mtls:
    mode: STRICT # strict mode
---
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: foo
spec:
  selector: # workload level
    matchLabels:
      app: finance
  mtls:
    mode: STRICT # mode
  portLevelMtls: # port of the workload
    8080:
      mode: DISABLE
---
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: foo
spec:
  selector: # workload
    matchLabels:
      app: finance
  mtls:
    mode: UNSET # use ns/mesh setting
  portLevelMtls:
    8080:
      mode: DISABLE
```

## Lab: mTLS

- Create no sidecar pod

```sh
# create app-no-sidecar
kubectl run app-no-sidecar --image=nginx -l app=app-no-sidecar
# pod/app-no-sidecar created

# create curl-no-sidecar
kubectl run curl-no-sidecar --image=alpine/curl -l app=curl-no-sidecar -- sleep 3600
# pod/curl-no-sidecar created

# expose
kubectl expose pod app-no-sidecar --port=80 --name=app-no-sidecar
# service/app-no-sidecar exposed

# confirm
kubectl get po --show-labels
# NAME              READY   STATUS    RESTARTS   AGE    LABELS
# app-no-sidecar    1/1     Running   0          6m3s   app=app-no-sidecar
# curl-no-sidecar   1/1     Running   0          20s    app=curl-no-sidecar
```

---

- enable sidecar

```sh
# Enable Side car injection for namespace
kubectl label namespace default istio-injection=enabled
# namespace/default labeled

# create app-sidecar
kubectl run app-sidecar --image=nginx -l app=app-sidecar
# pod/app-sidecar created

# create curl-sidecar
kubectl run curl-sidecar --image=alpine/curl -l app=curl-sidecar -- sleep 3600
# pod/curl-sidecar created

# expose
kubectl expose pod app-sidecar --port=80 --name=app-sidecar
# service/app-sidecar exposed

# confirm
kubectl get po --show-labels
# NAME              READY   STATUS    RESTARTS   AGE     LABELS
# app-no-sidecar    1/1     Running   0          13m     app=app-no-sidecar
# app-sidecar       2/2     Running   0          3m59s   app=app-sidecar,security.istio.io/tlsMode=istio,service.istio.io/canonical-name=app-sidecar,service.istio.io/canonical-revision=latest
# curl-no-sidecar   1/1     Running   0          7m22s   app=curl-no-sidecar
# curl-sidecar      2/2     Running   0          3m44s   app=curl-sidecar,security.istio.io/tlsMode=istio,service.istio.io/canonical-name=curl-sidecar,service.istio.io/canonical-revision=latest

kubectl get svc
# NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# app-no-sidecar   ClusterIP   10.102.249.61   <none>        80/TCP    5m25s
# app-sidecar      ClusterIP   10.110.20.121   <none>        80/TCP    4m45s

# enable peer authentication
cat << EOF | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
EOF
# peerauthentication.security.istio.io/default created

kubectl get pa
# NAME      MODE     AGE
# default   STRICT   12s

# ##############################
# validate
# ##############################
# from no sidecar
kubectl exec -it curl-no-sidecar -- curl -I http://app-no-sidecar.default.svc.cluster.local
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Thu, 10 Sep 2026 20:01:04 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

kubectl exec -it curl-no-sidecar -- curl -I http://app-sidecar.default.svc.cluster.local
# curl: (56) Recv failure: Connection reset by peer
# command terminated with exit code 56

# from sidecar
kubectl exec -it curl-sidecar -- curl -I http://app-no-sidecar.default.svc.cluster.local
# HTTP/1.1 200 OK
# server: envoy
# date: Thu, 10 Sep 2026 20:02:50 GMT
# content-type: text/html
# content-length: 896
# last-modified: Wed, 02 Sep 2026 11:17:13 GMT
# etag: "6a9805b9-380"
# accept-ranges: bytes
# x-envoy-upstream-service-time: 1

kubectl exec -it curl-sidecar -- curl -I http://app-sidecar.default.svc.cluster.local
# HTTP/1.1 200 OK
# server: envoy
# date: Thu, 10 Sep 2026 20:03:35 GMT
# content-type: text/html
# content-length: 896
# last-modified: Wed, 02 Sep 2026 11:17:13 GMT
# etag: "6a9805b9-380"
# accept-ranges: bytes
# x-envoy-upstream-service-time: 14
```

> key point is that `PeerAuthentication` controls **inbound traffic** at the destination’s Envoy proxy.
> For curl-sidecar → app-no-sidecar:
>
> 1. The request is intercepted by the client Envoy.
> 2. Envoy sees that the destination endpoint is not part of the mesh.
> 3. Automatic mTLS selects plaintext.
> 4. Nginx receives the request directly.

| Source          | app-no-sidecar | app-sidecar |
| --------------- | -------------- | ----------- |
| curl-no-sidecar | yes            | no          |
| curl-sidecar    | yes            | yes         |

- Check Certificate Related Information

```sh
# get secret for non-pa pod
istioctl proxy-config secret curl-no-sidecar
# 2026-09-10T20:14:47.925779Z     error   klog    an error occurred forwarding 40743 -> 15000: error forwarding port 15000 to pod 939066fe1004255bb3c61bfe1a8899b8d3e95da6837ab3e156d141da9dda15ce, uid : failed to execute portforward in network namespace "/var/run/netns/cni-42e4f29f-0d00-2821-906c-8f285de4266e": failed to connect to localhost:15000 inside namespace "939066fe1004255bb3c61bfe1a8899b8d3e95da6837ab3e156d141da9dda15ce", IPv4: dial tcp4 127.0.0.1:15000: connect: connection refused IPv6 dial tcp6: address localhost: no suitable address found : Unhandled Error     logger=UnhandledError
# 2026-09-10T20:14:47.926965Z     error   port forward failed: lost connection to pod
# Error: failed to execute command on curl-no-sidecar.default sidecar: failure running port forward process: Get "http://localhost:40743/config_dump?mask=dynamic_active_secrets,dynamic_warming_secrets": EOF


istioctl proxy-config secret curl-sidecar
# RESOURCE NAME     TYPE           STATUS     VALID CERT     SERIAL NUMBER                        NOT AFTER                NOT BEFORE
# default           Cert Chain     ACTIVE     true           7129d171351ab885ccd2d21f23582653     2026-09-11T19:51:52Z     2026-09-10T19:49:52Z
# ROOTCA            CA             ACTIVE     true           a91b8154aea27c21088f0da39cc56d42     2036-09-07T18:35:49Z     2026-09-10T18:35:49Z

istioctl proxy-config secret app-sidecar
# RESOURCE NAME     TYPE           STATUS     VALID CERT     SERIAL NUMBER                        NOT AFTER                NOT BEFORE
# default           Cert Chain     ACTIVE     true           ba4c024b0fea83e642b4ea6320139e68     2026-09-11T19:51:36Z     2026-09-10T19:49:36Z
# ROOTCA            CA             ACTIVE     true           a91b8154aea27c21088f0da39cc56d42     2036-09-07T18:35:49Z     2026-09-10T18:35:49Z
```

- clean up

```sh
kubectl delete pa default
kubectl delete po --all
kubectl label ns default istio-injection-
```
