# CKS: `kubelet`

[Back](../README.md)

- [CKS: `kubelet`](#cks-kubelet)
  - [`kubelet`](#kubelet)
  - [Authentication](#authentication)
  - [Authorization Mode](#authorization-mode)
  - [mTLS - Client Certificates](#mtls---client-certificates)
    - [HTTPS for Kubelet](#https-for-kubelet)
  - [Lab: mTLS](#lab-mtls)
  - [Lab: Authentication and Authorization mode](#lab-authentication-and-authorization-mode)

---

## `kubelet`

- `Kubelet API`
  - provides a set of endpoints that **allow users to interact** with the `Kubelet` to retrieve information about the node, running pods, and container statuses.
- port: 10250
  - `https://<node-ip>:10250/`

- example:

```sh
ip a
# 192.168.10.180

curl -k https://192.168.10.180:10250/pods
```

---

## Authentication

- Anonymous Authentication

- `Anonymous authentication`
  - allows **unauthenticated requests** to the Kubelet API.
  - used as a **fallback** mechanism when no other authentication method is provided.

- best practices: disable
  - kubelet use a yaml file to configure

```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false # Anonymous Authentication
```

---

## Authorization Mode

- `Kubelet` supports different authorization modes to control which requests are allowed.

| Feature                     | AlwaysAllow            | WebHook                                 |
| --------------------------- | ---------------------- | --------------------------------------- |
| Security Level              | Low (No authorization) | High (Centralized authorization)        |
| Use Case                    | Development, testing   | Production, fine-grained access control |
| Authorization Mechanism     | Allows all requests    | Uses an external webhook to decide      |
| Recommended for Production? | No                     | Yes                                     |

- kubelet config

```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authorization:
  mode: Webhook
```

---

## mTLS - Client Certificates

- When a **client** (such as kube-apiserver or other components) connects to the kubelet API, it must **present a TLS certificate**.
- The kubelet **verifies** the presented client certificate **against the CA certificate** stored defined through `clientCAfile` option.

---

### HTTPS for Kubelet

- The `--tls-cert-file` and `--tls-private-key-file` allow you to specify path of certificate and key used for serving HTTPS request at kubelet.
- If `--tls-cert-file` and `--tls-private-key-file` are not provided, a self-signed certificate and key are generated.

---

## Lab: mTLS

- access kubelet api in worker node from controlplane
  - using kubelet client cert for apiserver
  - demo show access via curl to simulate apiserver

```sh
# get worker node ip
kubectl get node -o wide
# NAME           STATUS   ROLES    AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# controlplane   Ready    <none>   2d13h   v1.35.8   192.168.10.180   <none>        Ubuntu 24.04.4 LTS   7.0.0-30-generic    containerd://2.2.1
# node01         Ready    <none>   2d12h   v1.35.8   192.168.10.181   <none>        Ubuntu 24.04.4 LTS   6.11.0-26-generic   containerd://2.2.1

# get kubelet key and crt
cd /etc/kubernetes/pki
ll apiserver-kubelet-client.crt apiserver-kubelet-client.key
# -rw-r--r-- 1 root root 1253 Sep  3 22:32 apiserver-kubelet-client.crt
# -rw------- 1 root root 1704 Sep  3 22:32 apiserver-kubelet-client.key

# access worker node kubelet api without cert
sudo curl -k https://192.168.10.180:10250/pods
# Forbidden (user=system:anonymous, verb=get, resource=nodes, subresource(s)=[pods proxy])

# access with cert
sudo curl -k --cert apiserver-kubelet-client.crt --key apiserver-kubelet-client.key https://192.168.10.180:10250/pods | jq
# {
#   "kind": "PodList",
#   "apiVersion": "v1",
#   "metadata": {},
#   "items": [
#     {
#       "metadata": {
#         "name": "tigera-operator-676bbdd645-lw8fw",
#         "generateName": "tigera-operator-676bbdd645-",
#         "namespace": "tigera-operator",
#         "uid": "2050db13-6955-4502-99cd-1af50094823b",
#         "resourceVersion": "6203",
#         "generation": 1,
#         "creationTimestamp": "2026-09-04T02:56:59Z",
#         "labels": {
#           "k8s-app": "tigera-operator",
#           "name": "tigera-operator",
#           "pod-template-hash": "676bbdd645"
#         },
#         "annotations": {
#           "kubernetes.io/config.seen": "2026-09-06T12:13:07.568395776-04:00",
#           "kubernetes.io/config.source": "api"
#         },
# ...
```

---

## Lab: Authentication and Authorization mode

```sh
# worker node
ss -ntlp | grep 10250
# LISTEN 0      4096               *:10250            *:*

#
curl -k -X GET https://localhost:10250/pods
# Forbidden (user=system:anonymous, verb=get, resource=nodes, subresource(s)=[pods proxy])

cd /var/lib/kubelet
ll node01.crt node01.key
# -rw-r--r-- 1 root root 1285 Sep  3 23:48 node01.crt
# -rw------- 1 root root 1704 Sep  3 23:49 node01.key



# ##############################
# enable anonymous, and AlwaysAllow mode
# ##############################
sudo nano /var/lib/kubelet/kubelet-config.yaml
# kind: KubeletConfiguration
# authentication:
#   anonymous:
#     enabled: true
# authorization:
#   mode: AlwaysAllow

sudo systemctl restart kubelet
sudo systemctl status kubelet

# test kubelet api endpoint
curl -k -X GET https://localhost:10250/pods
# {
#   "kind": "PodList",
#   "apiVersion": "v1",
#   "metadata": {},
#   "items": [
#     {
#       "metadata": {
#         "name": "csi-node-driver-wnx8x",
#         "generateName": "csi-node-driver-",
#         "namespace": "calico-system",
#         "uid": "b1418c4b-13e8-4a44-b207-692af582b82a",
#         "resourceVersion": "6502",
#         "generation": 1,
#         "creationTimestamp": "2026-09-04T03:49:55Z",

# ##############################
# disable AlwaysAllow mode
# ##############################
sudo nano /var/lib/kubelet/kubelet-config.yaml
# kind: KubeletConfiguration
# authentication:
#   anonymous:
#     enabled: true
# authorization:
#  mode: Webhook

sudo systemctl restart kubelet
sudo systemctl status kubelet

# test
curl -k -X GET https://localhost:10250/pods
# Forbidden (user=system:anonymous, verb=get, resource=nodes, subresource(s)=[pods proxy])

# ##############################
# disable anonymous auth
# ##############################
sudo nano /var/lib/kubelet/kubelet-config.yaml
# kind: KubeletConfiguration
# authentication:
#   anonymous:
#     enabled: false
# authorization:
#  mode: Webhook

sudo systemctl restart kubelet
sudo systemctl status kubelet --no-page

# test
curl -k -X GET https://localhost:10250/pods
# Unauthorized

# ##############################
# access with key: authen pass; author fails
# ##############################
cd /var/lib/kubelet
ll node01.crt node01.key
# -rw-r--r-- 1 root root 1285 Sep  3 23:48 node01.crt
# -rw------- 1 root root 1704 Sep  3 23:49 node01.key

# access with key
sudo curl -k --cert node01.crt --key node01.key https://192.168.10.180:10250/pods
# Forbidden (user=system:node:node01, verb=get, resource=nodes, subresource(s)=[pods proxy])
```
