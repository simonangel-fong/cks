# CKS: Cluster Authorization

[Back](../README.md)

- [CKS: Cluster Authorization](#cks-cluster-authorization)
  - [Authorization](#authorization)
    - [Authorization Modes](#authorization-modes)
    - [`system:masters` group](#systemmasters-group)
  - [Lab: authorization mode](#lab-authorization-mode)
    - [AlwaysDeny](#alwaysdeny)
    - [RBAC](#rbac)

---

## Authorization

- ref: https://kubernetes.io/docs/reference/access-authn-authz/authorization/

- `Authorization`
  - the process of **determining** what an authenticated user or entity **is allowed to do**
  - takes place following authentication.

### Authorization Modes

| Authorization Modes   | Description                                                                    |
| --------------------- | ------------------------------------------------------------------------------ |
| AlwaysAllow (default) | **Risky**. Allows all requests; use if you don’t need authorization.           |
| AlwaysDeny            | **only for testing**. Blocks all requests                                      |
| RBAC                  | **Recommended**. Allows to create and store policies using the Kubernetes API. |
| Node                  | A special-purpose authorization mode that grants permissions to kubelets       |

- flags `--authorization-mode`
  - Defaults to `AlwaysAllow`
  - e.g., `--authorization-mode=Node,RBAC `

---

### `system:masters` group

- **super-user group** in Kubernetes
  - grants **unrestricted, full cluster-admin access** to the API server

- Even if every cluster role and role is deleted from the cluster, users who are members of this group retain full access to the cluster.

- add a user as master group

```sh
openssl req -new -key alice.key -subj "/CN=alice/O=admins" -out alice.csr
```

---

## Lab: authorization mode

### AlwaysDeny

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

### RBAC

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
