# CKS: Cluster authentication

[Back](../README.md)

- [CKS: Cluster authentication](#cks-cluster-authentication)
  - [Authentication](#authentication)
    - [Categories of Users](#categories-of-users)
  - [Client Certificates(x509)](#client-certificatesx509)
    - [Lab: client certificate](#lab-client-certificate)
  - [Static Token file](#static-token-file)
    - [Lab: Static Token file](#lab-static-token-file)

---

## Authentication

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#authentication-methods

- `Authentication`
  - the process of **verifying a user's identity** _before_ granting them access to a system or resource

- Kubernetes does **not manage** the **user accounts** natively
  - Normal users cannot be added to a cluster through an `API call`

- Common methods

| Authentication Modes      | Description                                         |
| ------------------------- | --------------------------------------------------- |
| Client Certificates(X509) | Valid **client certificates** signed by trusted CA. |
| Static Token File         | Sets of **bearer token** mentioned in a file.       |
| Service Account Tokens    |

---

### Categories of Users

Kubernetes Clusters have two categories of users:

1. Normal Users (for humans): use certification authentication
2. `Service Accounts` (for apps): used within cluster, managed by cluster.

---

## Client Certificates(x509)

- A request is **authenticated** if the `client certificate` is signed by one of the `certificate authorities` that is configured in the API server.

- apiserver flag:
  - `--client-ca-file=/etc/kubernetes/pki/ca.crt`
  - any request presenting a `client certificate` **signed by one of the authorities** in the `client-ca-file` is **authenticated** with an identity corresponding to the CommonName of the client certificate.

---

- Disadvantage
  - The `private key` is **stored on an insecure media** (local disk storage).
  - Certificates are generally **long-lived**. Kubernetes does **not support** certificate **revocation** related area.
  - **Groups** are associated with **Organization** in certificate.
    - If you want to change the group, you will shave to **issue a new certificate**.

---

### Lab: client certificate

```sh
# confirm current client ca
sudo cat /etc/systemd/system/kube-apiserver.service | grep "client-ca"
  # --client-ca-file=/etc/kubernetes/pki/ca.crt \

# ca crt and key
ls /etc/kubernetes/pki/ca*
# /etc/kubernetes/pki/ca.crt  /etc/kubernetes/pki/ca.key

# create new cert and sign with ca
mkdir -pv ~/authen/cert
cd ~/authen/cert

# private key
openssl genrsa -out alice.key 2048
# csr
openssl req -new -key alice.key -subj "/CN=alice/O=developers" -out alice.csr
# signed cert
sudo openssl x509 -req -in alice.csr -CA /etc/kubernetes/pki/ca.crt
 -CAkey /etc/kubernetes/pki/ca.key  -CAcreateserial -out alice.crt -days 1000
# Certificate request self-signature ok
# subject=CN = alice, O = developer

ls
# alice.crt  alice.csr  alice.key

# test: access by crt and key with the trusted ca
kubectl get secret -A --server=https://127.0.0.1:6443 --certificate
-authority /etc/kubernetes/pki/ca.crt --client-certificate alice.crt --client-key alice.key
# NAMESPACE         NAME                          TYPE     DATA   AGE
# calico-system     calico-apiserver-certs        Opaque   2      42h
# calico-system     goldmane-key-pair             Opaque   2      42h
# calico-system     node-certs                    Opaque   2      42h
# calico-system     typha-certs                   Opaque   2      42h

```

---

## Static Token file

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file

- The API server **reads bearer tokens** from a file
- apiserver flag: `--token-auth-file=SOMEFILE`
  - e.g., `--token-auth-file=/root/token.csv`

- request header:
  - key: `Authorization`
  - value: `Bearer token_value`
  - e.g., `"Authorization: Bearer A342GHS3#"`

- workflow:
  - create token file in the format: `token,user,uid,"group1,group2,group3"`
  - add apiserver flag `--token-auth-file=<SOMEFILE>`
  - restart apiserver
  - test with `curl -k --header "Authorization: Bearer token_value" https://localhost:6443`

---

- it is **recommended to not use** this type of authentication.
  - The tokens are stored in **clear-text** in a file on the `apiserver`
  - Tokens **cannot be revoked or rotated** without restarting the apiserver.

---

### Lab: Static Token file

```sh
mkdir -pv ~/authen/static
cd ~/authen/static

tee ~/authen/static/token.csv <<"EOF"
Dem0Passw0rd#,bob,01,admins
adRUPoinIOBO#,alice,02,admins
EOF

sudo vim /etc/systemd/system/kube-apiserver.service
# add
# --token-auth-file=/home/ubuntuadmin/authen/static/token.csv   \
# comment out if applied
#   --authorization-mode=Node,RBAC \

# reload config
sudo systemctl daemon-reload
# restart
sudo systemctl restart kube-apiserver

# test access
curl -k --header "Authorization: Bearer Dem0Passw0rd#" https://localhost:6443
# {
#   "paths": [
#     "/.well-known/openid-configuration",
#     "/api",
#     "/api/v1",
#     "/apis",
#     "/apis/",
#     "/apis/admissionregistration.k8s.io",
#     "/apis/admissionregistration.k8s.io/v1",
#     "/apis/apiextensions.k8s.io",
# ...

# create object with token
kubectl get pod -A --server=https://localhost:6443 --token Dem0Passw0rd# --insecure-skip-tls-verify
# NAMESPACE         NAME                                       READY   STATUS    RESTARTS         AGE
# calico-system     calico-apiserver-64d74c9474-gtsgf          1/1     Running   1 (20m ago)      28h
# calico-system     calico-apiserver-64d74c9474-vk6xv          1/1     Running   1 (20m ago)      28h
# calico-system     calico-kube-controllers-5b5647977c-wp525   1/1     Running   1 (20m ago)      28h
# ...

kubectl create secret generic my-secret --server=https://localhost:6443 --token Dem0Passw0rd# --insecure-skip-tls-verify
# secret/my-secret created

kubectl get secret my-secret --server=https://localhost:6443 --token Dem0Passw0rd# --insecure-skip-tls-verify
# NAME        TYPE     DATA   AGE
# my-secret   Opaque   0      33s

kubectl delete secret my-secret --server=https://localhost:6443 --token Dem0Passw0rd# --insecure-skip-tls-verify
# secret "my-secret" deleted from default namespace
```

- Downside

```sh
# remove bob from csv
tee ~/authen/static/token.csv <<"EOF"
adRUPoinIOBO#,alice,02,admins
EOF

# test bob access
curl -k --header "Authorization: Bearer Dem0Passw0rd#" https://localhost:6443
# {
#   "paths": [
#     "/.well-known/openid-configuration",
#     "/api",
#     "/api/v1",
#     "/apis",
#     "/apis/",

# reload config
sudo systemctl daemon-reload
# restart
sudo systemctl restart kube-apiserver

# update only when restart
curl -k --header "Authorization: Bearer Dem0Passw0rd#" https://localhost:6443
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "Unauthorized",
#   "reason": "Unauthorized",
#   "code": 401
# }
```

---
