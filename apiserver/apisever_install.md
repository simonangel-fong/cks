# CKS: `kube-apiserver` - install

[Back](../README.md)

- [CKS: `kube-apiserver` - install](#cks-kube-apiserver---install)
  - [Assumptions](#assumptions)
  - [Download and install kube-apiserver](#download-and-install-kube-apiserver)
  - [Create certificate - API server](#create-certificate---api-server)
  - [Create certificate - etcd client](#create-certificate---etcd-client)
  - [Create key pair - service account token](#create-key-pair---service-account-token)
  - [Install certificates](#install-certificates)
  - [Configure systemd](#configure-systemd)
  - [Test](#test)

---

## Assumptions

- CA: `~/cert/ca/ca.crt` and `~/cert/ca/ca.key`
- `etcd` listening on `https://127.0.0.1:2379` with client certificate authentication
- Complete the [etcd install note](../etcd/etcd_install.md) first; it installs `/etc/kubernetes/pki/ca.crt`.

---

## Download and install kube-apiserver

```sh
K8S_VERSION=v1.35.0 # pinned lab version
ARCH=amd64         # use arm64 for ARM Linux
DOWNLOAD_DIR=$(mktemp -d)

# download
curl -fL -o "$DOWNLOAD_DIR/kube-apiserver" "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kube-apiserver"
# install
sudo install -m 0755 "$DOWNLOAD_DIR/kube-apiserver" /usr/local/bin/

# confirm
kube-apiserver --version
# Kubernetes v1.35.0
```

## Create certificate - API server

- `SANs` must match the IP or DNS name used to connect.
- `serverAuth` identifies a TLS server.

```sh
umask 077
mkdir -p ~/cert/apiserver
cd ~/cert/apiserver

APISERVER_IP=172.27.224.217

# create private key
openssl genrsa -out apiserver.key 2048
# create csr
openssl req -new -key apiserver.key -subj "/CN=kube-apiserver" -out apiserver.csr

# create signing config
cat > apiserver.ext <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:${APISERVER_IP},IP:127.0.0.1,IP:10.96.0.1,DNS:localhost,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local
EOF

# sign
openssl x509 -req -in apiserver.csr \
  -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -CAcreateserial \
  -out apiserver.crt -days 365 -sha256 -extfile apiserver.ext

# Certificate request self-signature ok
# subject=CN = kube-apiserver

# confirm
ls apiserver*
# apiserver.crt  apiserver.csr  apiserver.ext  apiserver.key

# verify
openssl verify -CAfile ~/cert/ca/ca.crt -purpose sslserver -verify_ip "$APISERVER_IP" apiserver.crt
# apiserver.crt: OK
```

## Create certificate - etcd client

Create a separate client certificate/key in `~/cert/apiserver`, signed by the same CA used by `etcd`.

```sh
cd ~/cert/apiserver

# create private key
openssl genrsa -out apiserver-etcd-client.key 2048
# create csr
openssl req -new -key apiserver-etcd-client.key -subj "/CN=kube-apiserver-etcd-client" -out apiserver-etcd-client.csr

# create signing config
cat > client.ext <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
EOF

# sign
openssl x509 -req -in apiserver-etcd-client.csr -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -CAcreateserial -out apiserver-etcd-client.crt -days 365 -sha256 -extfile client.ext
# Certificate request self-signature ok
# subject=CN = kube-apiserver-etcd-client

# confirm
ls apiserver-etcd*
# apiserver-etcd-client.crt  apiserver-etcd-client.csr  apiserver-etcd-client.key

# verify
openssl verify -CAfile ~/cert/ca/ca.crt -purpose sslclient apiserver-etcd-client.crt
# apiserver-etcd-client.crt: OK
```

---

## Create key pair - service account token

```sh
cd ~/cert/apiserver

# service account token signing key and verification key
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub
# writing RSA key
```

## Install certificates

```sh
cd ~/cert/apiserver

# install certificates and public key
sudo install -v -m 0644 apiserver.crt sa.pub apiserver-etcd-client.crt /etc/kubernetes/pki/
# 'apiserver.crt' -> '/etc/kubernetes/pki/apiserver.crt'
# 'sa.pub' -> '/etc/kubernetes/pki/sa.pub'
# 'apiserver-etcd-client.crt' -> '/etc/kubernetes/pki/apiserver-etcd-client.crt'

# install keys
sudo install -v -m 0600 apiserver.key sa.key apiserver-etcd-client.key /etc/kubernetes/pki/
# 'apiserver.key' -> '/etc/kubernetes/pki/apiserver.key'
# 'sa.key' -> '/etc/kubernetes/pki/sa.key'
# 'apiserver-etcd-client.key' -> '/etc/kubernetes/pki/apiserver-etcd-client.key'
```

## Configure systemd

- `--tls-cert-file` / `--tls-private-key-file`: serve HTTPS to API clients.
- `--client-ca-file`: verify incoming client certificates.
- `--etcd-*`: connect to etcd using mTLS.
- `--authorization-mode=Node,RBAC`: authorize API requests.

```sh
# create systemd unit file
sudo tee /etc/systemd/system/kube-apiserver.service > /dev/null <<EOF
[Unit]
Description=Kubernetes API Server
Wants=network-online.target
After=network-online.target etcd.service

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${APISERVER_IP} \\
  --bind-address=0.0.0.0 \\
  --secure-port=6443 \\
  --service-cluster-ip-range=10.96.0.0/12 \\
  --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \\
  --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \\
  --client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --etcd-cafile=/etc/kubernetes/pki/ca.crt \\
  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \\
  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \\
  --authorization-mode=Node,RBAC \\
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
  --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \\
  --service-account-key-file=/etc/kubernetes/pki/sa.pub
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload
sudo systemctl daemon-reload
# enable
sudo systemctl enable --now kube-apiserver
# Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.

# confirm
sudo systemctl status kube-apiserver --no-pager
# ● kube-apiserver.service - Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-05 13:28:21 EDT; 2min 24s ago
#    Main PID: 10990 (kube-apiserver)
#       Tasks: 17 (limit: 9328)
#      Memory: 163.4M (peak: 177.4M)
#         CPU: 6.136s
#      CGroup: /system.slice/kube-apiserver.service

# If startup fails:
sudo journalctl -u kube-apiserver -n 30 --no-pager
# debug port
sudo ss -ltnp '( sport = :6443 )'
```

## Test

```sh
# test readiness
curl --fail --cacert ~/cert/ca/ca.crt https://127.0.0.1:6443/readyz && echo
# ok

# test list pods: fails, due to anonymous requests
curl --cacert ~/cert/ca/ca.crt https://127.0.0.1:6443/api/v1/pods && echo 
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "pods is forbidden: User \"system:anonymous\" cannot list resource \"pods\" in API group \"\" at the cluster scope",
#   "reason": "Forbidden",
#   "details": {
#     "kind": "pods"
#   },
#   "code": 403
# }
```
