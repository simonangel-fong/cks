# CKS - Master node: API Server

[Back](../../index.md)

- [CKS - Master node: API Server](#cks---master-node-api-server)
  - [API Server - Overview](#api-server---overview)
    - [Required files](#required-files)
    - [Identity table](#identity-table)
    - [`api server` certificate](#api-server-certificate)
    - [`etcd` client certificate](#etcd-client-certificate)
    - [`kubelet` client certificate](#kubelet-client-certificate)
    - [Service-account key pair](#service-account-key-pair)
    - [`front-proxy` certificates](#front-proxy-certificates)
    - [Install `kube-apiserver`](#install-kube-apiserver)
  - [Install `kubectl`](#install-kubectl)
  - [Configure admin kubeconfig](#configure-admin-kubeconfig)

---

## API Server - Overview

### Required files

Files required by the `kube-apiserver` systemd unit:

| File                           | Type                    | Purpose                                                  |
| ------------------------------ | ----------------------- | -------------------------------------------------------- |
| `ca.crt`                       | CA certificate          | Verifies API clients, etcd, and kubelet certificates     |
| `apiserver.crt`                | TLS serving certificate | Identifies the API server                                |
| `apiserver.key`                | Private key             | Private key for the API server certificate               |
| `apiserver-etcd-client.crt`    | Client certificate      | Authenticates the API server to etcd                     |
| `apiserver-etcd-client.key`    | Private key             | Private key for the etcd client certificate              |
| `apiserver-kubelet-client.crt` | Client certificate      | Authenticates the API server to kubelets                 |
| `apiserver-kubelet-client.key` | Private key             | Private key for the kubelet client certificate           |
| `sa.pub`                       | Public key              | Verifies service-account tokens                          |
| `sa.key`                       | Private key             | Signs service-account tokens                             |
| `front-proxy-ca.crt`           | CA certificate          | Verifies aggregation-layer clients                       |
| `front-proxy-client.crt`       | Client certificate      | Authenticates the API server to extension API servers    |
| `front-proxy-client.key`       | Private key             | Private key for the aggregation-layer client certificate |

- Networking:
  - Service CIDR: 10.96.0.0/12 (Default, about 1 million addresses)
  - etcd endpoint: 127.0.0.1:2379
  - API server port: 6443

---

### Identity table

| Certificate                     | CN                              | O                | Purpose                         |
| ------------------------------- | ------------------------------- | ---------------- | ------------------------------- |
| `apiserver.crt`                 | `kube-apiserver`                | `Kubernetes`     | Serves the Kubernetes API       |
| `apiserver-etcd-client.crt`     | `kube-apiserver-etcd-client`    | `Kubernetes`     | Authenticates to etcd           |
| `apiserver-kubelet-client.crt`  | `kube-apiserver-kubelet-client` | `system:masters` | Authenticates to kubelets       |
| `front-proxy-client.crt`        | `front-proxy-client`            | --               | Authenticates to extension APIs |

---

### `api server` certificate

```sh
cd ~/pki

# ##############################
# Create cert: api server
# ##############################
# conf file for csr
cat > apiserver.conf <<'EOF'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = kube-apiserver
O = Kubernetes

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = controlplane
DNS.6 = localhost
IP.1  = 10.96.0.1
IP.2  = 192.168.10.180
IP.3  = 127.0.0.1
EOF

# create private key
openssl genrsa -out apiserver.key 2048
# create csr with config file
openssl req -new -key apiserver.key -out apiserver.csr -config apiserver.conf
# sign csr with config file
openssl x509 -req -in apiserver.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out apiserver.crt -days 365 -sha256 \
  -extensions v3_ext -extfile apiserver.conf

# Certificate request self-signature ok
# subject=CN = kube-apiserver, O = Kubernetes

# verify certificate chain, usage, and SANs
openssl verify -CAfile ca.crt apiserver.crt
# apiserver.crt: OK

openssl x509 -in apiserver.crt -noout \
  -subject -issuer -ext extendedKeyUsage,subjectAltName

# subject=CN = kube-apiserver, O = Kubernetes
# issuer=CN = kubernetes-ca, O = Kubernetes
# X509v3 Extended Key Usage:
#     TLS Web Server Authentication
# X509v3 Subject Alternative Name:
#     DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, DNS:controlplane, DNS:localhost, IP Address:10.96.0.1, IP Address:192.168.10.180, IP Address:127.0.0.1


# remove the CSR
rm -fv apiserver.csr

# ##############################
# Install cert: API server
# ##############################
sudo install -v -m 644 apiserver.crt /etc/kubernetes/pki/apiserver.crt
# 'apiserver.crt' -> '/etc/kubernetes/pki/apiserver.crt'
sudo install -v -m 600 apiserver.key /etc/kubernetes/pki/apiserver.key
# 'apiserver.key' -> '/etc/kubernetes/pki/apiserver.key'

ls -l /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver.key
# -rw-r--r-- 1 root root 1440 Sep  3 12:48 /etc/kubernetes/pki/apiserver.crt
# -rw------- 1 root root 1704 Sep  3 12:48 /etc/kubernetes/pki/apiserver.key
```

---

### `etcd` client certificate

```sh
cd ~/pki

# ##############################
# Helper function
# ##############################
# Extensions for client certificates
cat > client-ext.conf <<'EOF'
[ v3_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
EOF

gen_client() {
  local name="$1" subj="$2"

  # Generate private key and CSR
  openssl genrsa -out "${name}.key" 2048
  openssl req -new -key "${name}.key" -out "${name}.csr" -subj "${subj}"

  # Sign the client certificate
  openssl x509 -req -in "${name}.csr" \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${name}.crt" -days 365 -sha256 \
    -extensions v3_ext -extfile client-ext.conf

  # Remove the CSR
  rm -fv "${name}.csr"
}

# ##############################
# Create the API server's etcd client certificate
# ##############################
gen_client apiserver-etcd-client "/CN=kube-apiserver-etcd-client/O=Kubernetes"
# Certificate request self-signature ok
# subject=CN = kube-apiserver-etcd-client, O = Kubernetes
# removed 'apiserver-etcd-client.csr'

# Verify certificate chain and usage
openssl verify -CAfile ca.crt apiserver-etcd-client.crt
# apiserver-etcd-client.crt: OK

openssl x509 -in apiserver-etcd-client.crt -noout \
  -subject -issuer -ext extendedKeyUsage

# subject=CN = kube-apiserver-etcd-client, O = Kubernetes
# issuer=CN = kubernetes-ca, O = Kubernetes
# X509v3 Extended Key Usage:
#     TLS Web Client Authentication


# ##############################
# Install the etcd client certificate
# ##############################
sudo install -v -m 644 apiserver-etcd-client.crt /etc/kubernetes/pki/apiserver-etcd-client.crt
# 'apiserver-etcd-client.crt' -> '/etc/kubernetes/pki/apiserver-etcd-client.crt'
sudo install -v -m 600 apiserver-etcd-client.key /etc/kubernetes/pki/apiserver-etcd-client.key
# 'apiserver-etcd-client.key' -> '/etc/kubernetes/pki/apiserver-etcd-client.key'
ls -l /etc/kubernetes/pki/apiserver-etcd-client.crt /etc/kubernetes/pki/apiserver-etcd-client.key
# -rw-r--r-- 1 root root 1245 Sep  3 12:49 /etc/kubernetes/pki/apiserver-etcd-client.crt
# -rw------- 1 root root 1704 Sep  3 12:50 /etc/kubernetes/pki/apiserver-etcd-client.key
```

---

### `kubelet` client certificate

```sh
# ##############################
# Create the API server's kubelet client certificate
# ##############################
gen_client apiserver-kubelet-client "/CN=kube-apiserver-kubelet-client/O=system:masters"
# Certificate request self-signature ok
# subject=CN = kube-apiserver-kubelet-client, O = system:masters
# removed 'apiserver-kubelet-client.csr'

# Verify certificate chain and usage
openssl verify -CAfile ca.crt apiserver-kubelet-client.crt
# apiserver-kubelet-client.crt: OK

openssl x509 -in apiserver-kubelet-client.crt -noout \
  -subject -issuer -ext extendedKeyUsage

# subject=CN = kube-apiserver-kubelet-client, O = system:masters
# issuer=CN = kubernetes-ca, O = Kubernetes
# X509v3 Extended Key Usage:
#     TLS Web Client Authentication

# ##############################
# Install the kubelet client certificate
# ##############################
sudo install -v -m 644 apiserver-kubelet-client.crt /etc/kubernetes/pki/apiserver-kubelet-client.crt
# 'apiserver-kubelet-client.crt' -> '/etc/kubernetes/pki/apiserver-kubelet-client.crt'

sudo install -v -m 600 apiserver-kubelet-client.key /etc/kubernetes/pki/apiserver-kubelet-client.key
# 'apiserver-kubelet-client.key' -> '/etc/kubernetes/pki/apiserver-kubelet-client.key'

ls -l /etc/kubernetes/pki/apiserver-kubelet-client.crt /etc/kubernetes/pki/apiserver-kubelet-client.key
# -rw-r--r-- 1 root root 1253 Sep  3 12:51 /etc/kubernetes/pki/apiserver-kubelet-client.crt
# -rw------- 1 root root 1704 Sep  3 12:51 /etc/kubernetes/pki/apiserver-kubelet-client.key
```

---

### Service-account key pair

```sh
cd ~/pki

# ##############################
# Create the service-account key pair
# ##############################
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub
# writing RSA key

# Verify the public key
openssl pkey -pubin -in sa.pub -noout -text


# ##############################
# Install the service-account key pair
# ##############################
sudo install -v -m 600 sa.key /etc/kubernetes/pki/sa.key
# 'sa.key' -> '/etc/kubernetes/pki/sa.key'
sudo install -v -m 644 sa.pub /etc/kubernetes/pki/sa.pub
# 'sa.pub' -> '/etc/kubernetes/pki/sa.pub'
ls -l /etc/kubernetes/pki/sa.key /etc/kubernetes/pki/sa.pub
# -rw------- 1 root root 1704 Sep  3 12:52 /etc/kubernetes/pki/sa.key
# -rw-r--r-- 1 root root  451 Sep  3 12:52 /etc/kubernetes/pki/sa.pub
```

---

### `front-proxy` certificates

```sh
cd ~/pki

# ##############################
# front-proxy CA
# ##############################
# create private key
openssl genrsa -out front-proxy-ca.key 2048

# create self-signed CA certificate
openssl req -x509 -new -noenc -key front-proxy-ca.key -sha256 -days 3650 \
  -subj "/CN=front-proxy-ca" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out front-proxy-ca.crt

# ##############################
# Install front-proxy CA
# ##############################
sudo install -v -m 644 front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-ca.crt
sudo install -v -m 600 front-proxy-ca.key /etc/kubernetes/pki/front-proxy-ca.key
# 'front-proxy-ca.crt' -> '/etc/kubernetes/pki/front-proxy-ca.crt'
# 'front-proxy-ca.key' -> '/etc/kubernetes/pki/front-proxy-ca.key'

# ##############################
# front-proxy client cert
# ##############################
# create private key
openssl genrsa -out front-proxy-client.key 2048

# create csr
openssl req -new -key front-proxy-client.key -out front-proxy-client.csr \
  -subj "/CN=front-proxy-client"

# sign the client certificate
openssl x509 -req -in front-proxy-client.csr \
  -CA front-proxy-ca.crt -CAkey front-proxy-ca.key -CAcreateserial \
  -out front-proxy-client.crt -days 365 -sha256 \
  -extensions v3_ext -extfile client-ext.conf

# Certificate request self-signature ok
# subject=CN = front-proxy-client

# remove csr
rm -fv front-proxy-client.csr
# removed 'front-proxy-client.csr'

# confirm: issuer must be front-proxy-ca, not kubernetes-ca
openssl x509 -in front-proxy-client.crt -noout -subject -issuer
# subject=CN = front-proxy-client
# issuer=CN = front-proxy-ca

# ##############################
# Install cert: front-proxy
# ##############################
sudo install -v -m 644 front-proxy-client.crt /etc/kubernetes/pki/front-proxy-client.crt
# 'front-proxy-client.crt' -> '/etc/kubernetes/pki/front-proxy-client.crt'

sudo install -v -m 600 front-proxy-client.key /etc/kubernetes/pki/front-proxy-client.key
# 'front-proxy-client.key' -> '/etc/kubernetes/pki/front-proxy-client.key'
```

---

### Install `kube-apiserver`

```sh
export K8S_VERSION=v1.35.8

# ##############################
# Download kube-apiserver
# ##############################
cd /tmp

curl -fL -o kube-apiserver "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kube-apiserver"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 82.7M  100 82.7M    0     0  11.9M      0  0:00:06  0:00:06 --:--:-- 13.5M

sudo install -v -m 755 kube-apiserver /usr/local/bin/
# 'kube-apiserver' -> '/usr/local/bin/kube-apiserver'

kube-apiserver --version
# Kubernetes v1.35.8

# ##############################
# Configure systemd unit: kube-apiserver
# ##############################
cat <<'EOF' | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://kubernetes.io/docs/concepts/overview/components/
After=etcd.service
Requires=etcd.service

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --advertise-address=192.168.10.180 \
  --secure-port=6443 \
  --service-cluster-ip-range=10.96.0.0/12 \
  --etcd-servers=https://127.0.0.1:2379 \
  --etcd-cafile=/etc/kubernetes/pki/ca.crt \
  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \
  --client-ca-file=/etc/kubernetes/pki/ca.crt \
  --anonymous-auth=false \
  --authorization-mode=Node,RBAC \
  --allow-privileged=true \
  --service-account-key-file=/etc/kubernetes/pki/sa.pub \
  --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \
  --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
  --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \
  --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt \
  --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key \
  --enable-admission-plugins=NodeRestriction \
  --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt \
  --requestheader-allowed-names=front-proxy-client \
  --requestheader-extra-headers-prefix=X-Remote-Extra- \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \
  --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload config
sudo systemctl daemon-reload
# start and enable
sudo systemctl enable --now kube-apiserver
# Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.

# confirm
sudo systemctl status kube-apiserver --no-pager
# ● kube-apiserver.service - Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: active (running) since Thu 2026-09-03 12:55:44 EDT; 11s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 2335 (kube-apiserver)
#       Tasks: 8 (limit: 3179)
#      Memory: 172.3M (peak: 172.6M)
#         CPU: 2.069s
#      CGroup: /system.slice/kube-apiserver.service
#              └─2335 /usr/local/bin/kube-apiserver --advertise-address=192.168.10.180 --secure-port=6443 --service-…

# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.498504    2335 storage_rbac.go:321] create…system
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.504736    2335 storage_rbac.go:321] create…system
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.508217    2335 storage_rbac.go:321] create…system
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.512086    2335 storage_rbac.go:321] create…system
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.514808    2335 storage_rbac.go:321] create…public
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.567762    2335 alloc.go:329] "allocated cl….0.1"}
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: W0903 12:55:47.574630    2335 lease.go:265] Resetting end…0.180]
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.578321    2335 controller.go:667] quota ad…points
# Sep 03 12:55:47 controlplane kube-apiserver[2335]: I0903 12:55:47.587392    2335 controller.go:667] quota ad…k8s.io
# Sep 03 12:55:56 controlplane kube-apiserver[2335]: I0903 12:55:56.049116    2335 apf_controller.go:493] "Update Cu…
# Hint: Some lines were ellipsized, use -l to show in full.
```

---

## Install `kubectl`

```sh
# install kubectl
export K8S_VERSION=v1.35.8
curl -fLO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 59.0M  100 59.0M    0     0  6198k      0  0:00:09  0:00:09 --:--:-- 6964k

sudo install -v -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# 'kubectl' -> '/usr/local/bin/kubectl

kubectl version --client
# Client Version: v1.35.8
```

---

## Configure admin kubeconfig

```sh
cd ~/pki

# ##############################
# Create client cert: admin
# ##############################
# create client certificates: admin
gen_client admin "/CN=admin/O=system:masters"
# Certificate request self-signature ok
# subject=CN = admin, O = system:masters
# removed 'admin.csr'

ls -l admin.*
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin 1220 Sep  3 16:13 admin.crt
# -rw------- 1 ubuntuadmin ubuntuadmin 1704 Sep  3 16:13 admin.key

# verify
openssl x509 -in "admin.crt" -noout -subject
# subject=CN = admin, O = system:masters

# ##############################
# Configure kubeconfig: admin
# ##############################
# set cluster
kubectl config set-cluster kubernetes \
  --server=https://127.0.0.1:6443 \
  --certificate-authority=ca.crt  \
  --embed-certs=true \
  --kubeconfig=admin.config

# Cluster "kubernetes" set.

# set user
kubectl config set-credentials admin \
  --client-certificate=admin.crt  \
  --client-key=admin.key \
  --embed-certs=true  \
  --kubeconfig=admin.config

# User "admin" set.

# set context
kubectl config set-context default  \
  --cluster=kubernetes \
  --user=admin  \
  --kubeconfig=admin.config

# Context "default" created.

kubectl config use-context default --kubeconfig=admin.config
# Switched to context "default".

# ##############################
# Install kubeconfigs: admin
# ##############################
mkdir -pv ~/.kube
# mkdir: created directory '/home/ubuntuadmin/.kube'
cp -v admin.config ~/.kube/config
# 'admin.config' -> '/home/ubuntuadmin/.kube/config'

# set permissions
chmod -v 600 ~/.kube/config
# mode of '/home/ubuntuadmin/.kube/config' retained as 0600 (rw-------)

# ##############################
# Confirm kubeconfig
# ##############################
kubectl config view -o jsonpath='{.users[0].name} -> {.clusters[0].cluster.server}'; echo
# admin -> https://127.0.0.1:6443
```
