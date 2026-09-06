# CKS: Fundamental - Access Control

[back](../README.md)

- [CKS: Fundamental - Access Control](#cks-fundamental---access-control)
  - [Access Control](#access-control)
  - [Authentication](#authentication)
    - [X509 Client Certificates](#x509-client-certificates)
      - [Lab: client certificate](#lab-client-certificate)
    - [Static Token file](#static-token-file)
      - [Lab: Static Token file](#lab-static-token-file)
  - [Authorization](#authorization)
      - [`system:masters` group](#systemmasters-group)
      - [Lab: authorization mode](#lab-authorization-mode)
        - [AlwaysDeny](#alwaysdeny)
        - [RBAC](#rbac)
    - [Admission Controllers](#admission-controllers)

---

## Access Control

When a request reaches the API, it goes through several stages:

1. Authentication
2. Authorization
3. Admission Controllers
4. K8s object

---

## Authentication

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#authentication-methods

- Common methods

| Authentication Modes         | Description                                         |
| ---------------------------- | --------------------------------------------------- |
| X509 Client **Certificates** | Valid **client certificates** signed by trusted CA. |
| Static Token File            | Sets of **bearer token** mentioned in a file.       |

---

### X509 Client Certificates

- A request is **authenticated** if the `client certificate` is signed by one of the `certificate authorities` that is configured in the API server.

- apiserver flag:
  - `--client-ca-file=/etc/kubernetes/pki/ca.crt`
  - any request presenting a `client certificate` **signed by one of the authorities** in the `client-ca-file` is **authenticated** with an identity corresponding to the CommonName of the client certificate.

- Disadvantage
  - The `private key` is **stored on an insecure media** (local disk storage).
  - Certificates are generally **long-lived**. Kubernetes does **not support** certificate **revocation** related area.
  - **Groups** are associated with **Organization** in certificate.
    - If you want to change the group, you will shave to **issue a new certificate**.

---

#### Lab: client certificate

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

### Static Token file

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file

- The API server **reads bearer tokens** from a file
  - command option `--token-auth-file=SOMEFILE`
- request header:
  - key: `Authorization`
  - value: `Bearer token_value`
  - e.g., `"Authorization: Bearer A342GHS3#"`

- it is recommended to not use this type of authentication.
  - The tokens are stored in **clear-text** in a file on the `apiserver`
  - Tokens **cannot be revoked or rotated** without restarting the apiserver.

- workflow:
  - create token file in the format: `token,user,uid,"group1,group2,group3"`
  - add apiserver flag `--token-auth-file=<SOMEFILE>`
  - restart apiserver
  - test with `curl -k --header "Authorization: Bearer token_value" https://localhost:6443`

---

#### Lab: Static Token file

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

## Authorization

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authorization/

**After** the request is authenticated as coming from a specific user, the request must be **authorized**.

- Multiple authorization modules are supported.

| Authorization Modes   | Description                                                              |
| --------------------- | ------------------------------------------------------------------------ |
| AlwaysAllow (default) | Allows all requests; use if you don’t need authorization.                |
| AlwaysDeny            | Blocks all requests (used in tests).                                     |
| RBAC                  | Allows you to create and store policies using the Kubernetes API.        |
| Node                  | A special-purpose authorization mode that grants permissions to kubelets |

- flags `--authorization-mode`
  - Defaults to `AlwaysAllow`
  - e.g., `--authorization-mode=Node,RBAC `

---

#### `system:masters` group

- **super-user group** in Kubernetes
  - grants **unrestricted, full cluster-admin access** to the API server

- Even if every cluster role and role is deleted from the cluster, users who are members of this group retain full access to the cluster.

- add a user as master group

```sh
openssl req -new -key alice.key -subj "/CN=alice/O=admins" -out alice.csr
```

---

#### Lab: authorization mode

##### AlwaysDeny

```sh
# before config: disable --authorization-mode
# can list
kubectl get secret -A --server=https://127.0.0.1:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --client-certificate alice.crt --client-key alice.key
# NAMESPACE         NAME                          TYPE     DATA   AGE
# calico-system     calico-apiserver-certs        Opaque   2      43h
# calico-system     goldmane-key-pair             Opaque   2      43h
# ...

sudo vim /etc/systemd/system/kube-apiserver.service
# change mode
# --authorization-mode=AlwaysDeny

sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver && sudo systemctl status kube-apiserver --no-page

# test: Everything is forbidden.
kubectl get secret -A --server=https://127.0.0.1:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --client-certificate alice.crt --client-key alice.key
# Error from server (Forbidden): secrets is forbidden: User "alice" cannot list resource "secrets" in API group "" at the cluster scope: Everything is forbidden.
```

- Create supper user

```sh
mkdir -pv ~/author/
# mkdir: created directory '/home/ubuntuadmin/author/'
cd ~/author/

# get ca
sudo cat /etc/systemd/system/kube-apiserver.service | grep "client-ca"
#   --client-ca-file=/etc/kubernetes/pki/ca.crt \

# confirm still deny all
sudo cat /etc/systemd/system/kube-apiserver.service | grep authorization
  # --authorization-mode=AlwaysDeny       \

cd ~/authen/cert

# create private key
openssl genrsa -out calvin.key 2048
# create csr
openssl req -new -key calvin.key -subj "/CN=calvin/O=system:masters" -out calvin.csr
# sign cert
sudo openssl x509 -req -in calvin.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out calvin.crt -days 1000
# Certificate request self-signature ok
# subject=CN = calvin, O = system:masters

# test with supper user
kubectl get secret -A --server=https://127.0.0.1:6443 --client-certificate calvin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key calvin.key
# NAMESPACE         NAME                          TYPE     DATA   AGE
# calico-system     calico-apiserver-certs        Opaque   2      43h
# calico-system     goldmane-key-pair             Opaque   2      43h
# calico-system     node-certs                    Opaque   2      43h
# calico-system     typha-certs                   Opaque   2      43h
# ...
```

##### RBAC

```sh
sudo vim /etc/systemd/system/kube-apiserver.service
# change mode
# --authorization-mode=RBAC

sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver
sudo systemctl status kube-apiserver --no-page

cd ~/authen/cert

# test: RBAC deny
kubectl get secret -A --server=https://127.0.0.1:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --client-certificate alice.crt --client-key alice.key
# Error from server (Forbidden): secrets is forbidden: User "alice" cannot list resource "secrets" in API group "" at the cluster scope

# create clusterrole, clusterrolebinding
# use default admin
kubectl create clusterrole alice-list-secrets --verb=list --resource=secrets
# clusterrole.rbac.authorization.k8s.io/alice-list-secrets created

kubectl create clusterrolebinding alice-list-secrets --clusterrole=alice-list-secrets --user=alice
# clusterrolebinding.rbac.authorization.k8s.io/alice-list-secrets created

kubectl get secret -A --server=https://127.0.0.1:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --client-certificate alice.crt --client-key alice.key
# NAMESPACE         NAME                          TYPE     DATA   AGE
# calico-system     calico-apiserver-certs        Opaque   2      43h
# calico-system     goldmane-key-pair             Opaque   2      43h
# calico-system     node-certs                    Opaque   2      43h
# ...
```

---

### Admission Controllers

- ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

- `admission controller`
  - a **piece of code** that **intercepts requests** to the Kubernetes API server **after** the user is successfully **authenticated and authorized**, but **before** the data is saved to etcd (the cluster's database).

- Two Phases of Admission Control

1. `Mutating Phase`:
   - **modify** or "mutate" the resource object being created or updated.
   - e.g., automatically inject a sidecar proxy container (like Istio) or add default resource limits if a developer forgot to include them.
2. `Validating Phase`:
   - **evaluate** the final version of the object and can only say "yes" or "no".
   - If any single validating controller rejects the request, the entire operation fails, and an error is sent back to the user.
   - This phase happens last so that it can inspect any changes made during the mutating phase.
