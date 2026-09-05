# CKS: `etcd` - install

[Back](../README.md)

- [CKS: `etcd` - install](#cks-etcd---install)
  - [Download and install etcd](#download-and-install-etcd)
  - [Create CA](#create-ca)
  - [Create etcd server certificate](#create-etcd-server-certificate)
  - [Create client certificate - apiserver](#create-client-certificate---apiserver)
  - [Install certificates and prepare data directory](#install-certificates-and-prepare-data-directory)
  - [Configure systemd](#configure-systemd)
  - [Verify mTLS](#verify-mtls)

---

## Download and install etcd

```sh
ETCD_VERSION=v3.6.0 # pinned lab version
ARCH=amd64         # use arm64 for ARM Linux
DOWNLOAD_DIR=$(mktemp -d)

# download
curl -fL -o "$DOWNLOAD_DIR/etcd.tar.gz" "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz"
# unzip
tar -xzf "$DOWNLOAD_DIR/etcd.tar.gz" -C "$DOWNLOAD_DIR"

# install etcd
sudo install -m 0755 "$DOWNLOAD_DIR/etcd-${ETCD_VERSION}-linux-${ARCH}/"{etcd,etcdctl} /usr/local/bin/

# confirm
etcd --version
# etcd Version: 3.6.0
# Git SHA: f5d605a
# Go Version: go1.23.9
# Go OS/Arch: linux/amd64

etcdctl version
# etcdctl version: 3.6.0
# API version: 3.6
```

## Create CA

```sh
# default security permissions
umask 077
mkdir -pv ~/cert/ca
cd ~/cert/ca

# create private key
openssl genrsa -out ca.key 2048
# create cert
openssl req -x509 -new -sha256 -key ca.key -days 365 \
  -subj "/CN=KUBERNETES-CA" -out ca.crt \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

# confirm
ls
# ca.crt  ca.key
```

## Create etcd server certificate

SANs must match the address clients use; `serverAuth` identifies a TLS server.

```sh
mkdir -pv ~/cert/etcd
cd ~/cert/etcd

ETCD_IP=172.27.224.217

# create private key
openssl genrsa -out etcd.key 2048
# create csr
openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr
# cert config
cat > etcd.ext <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:${ETCD_IP},IP:127.0.0.1,DNS:localhost
EOF

# create cert
openssl x509 -req -in etcd.csr -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -CAcreateserial -out etcd.crt -days 365 -sha256 -extfile etcd.ext

# Certificate request self-signature ok
# subject=CN = etcd

# verify
openssl verify -CAfile ~/cert/ca/ca.crt -purpose sslserver -verify_ip "$ETCD_IP" etcd.crt
# etcd.crt: OK

ls etcd*
# etcd.crt  etcd.csr  etcd.ext  etcd.key
```

## Create client certificate - apiserver

Prepare the certificate now and use it with `etcdctl` for testing. `clientAuth` identifies a TLS client.

```sh
cd ~/cert/etcd

# create private key
openssl genrsa -out apiserver-etcd-client.key 2048
# create csr
openssl req -new -key apiserver-etcd-client.key -subj "/CN=kube-apiserver-etcd-client" -out apiserver-etcd-client.csr

# cert conf
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
ls
# apiserver-etcd-client.crt  apiserver-etcd-client.csr  apiserver-etcd-client.key  client.ext  etcd.crt  etcd.csr  etcd.ext  etcd.key

# verify
openssl verify -CAfile ~/cert/ca/ca.crt -purpose sslclient apiserver-etcd-client.crt
# apiserver-etcd-client.crt: OK
```

## Install certificates and prepare data directory

Keep `ca.key` in `~/cert/ca` and client files in `~/cert/etcd`. etcd only needs the CA certificate and its server certificate/key. `/var/lib/etcd` stores data, not binaries.

```sh
# create user
sudo useradd --system --no-create-home --shell /usr/sbin/nologin etcd
# create dir
sudo install -d -o etcd -g etcd -m 0700 /var/lib/etcd
sudo install -d -o root -g etcd -m 0750 /etc/kubernetes/pki
# copy
sudo install -v -o root -g etcd -m 0644 ~/cert/ca/ca.crt ~/cert/etcd/etcd.crt /etc/kubernetes/pki/
# '/home/ubuntuadmin/cert/ca/ca.crt' -> '/etc/kubernetes/pki/ca.crt'
# '/home/ubuntuadmin/cert/etcd/etcd.crt' -> '/etc/kubernetes/pki/etcd.crt'
sudo install -v -o root -g etcd -m 0640 ~/cert/etcd/etcd.key /etc/kubernetes/pki/
# '/home/ubuntuadmin/cert/etcd/etcd.key' -> '/etc/kubernetes/pki/etcd.key'
```

## Configure systemd

- flags:
  - `--client-cert-auth=true`: requires a client certificate signed by `--trusted-ca-file`;

```sh
ETCD_IP=172.27.224.217

# create unit file
sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF
[Unit]
Description=etcd
Wants=network-online.target
After=network-online.target

[Service]
User=etcd
Group=etcd
ExecStart=/usr/local/bin/etcd \\
  --name=etcd1 \\
  --data-dir=/var/lib/etcd \\
  --listen-client-urls=https://${ETCD_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls=https://${ETCD_IP}:2379 \\
  --listen-peer-urls=http://127.0.0.1:2380 \\
  --initial-advertise-peer-urls=http://127.0.0.1:2380 \\
  --initial-cluster=etcd1=http://127.0.0.1:2380 \\
  --initial-cluster-state=new \\
  --cert-file=/etc/kubernetes/pki/etcd.crt \\
  --key-file=/etc/kubernetes/pki/etcd.key \\
  --trusted-ca-file=/etc/kubernetes/pki/ca.crt \\
  --client-cert-auth=true
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload config
sudo systemctl daemon-reload
# start and enable
sudo systemctl enable --now etcd
# Created symlink /etc/systemd/system/multi-user.target.wants/etcd.service → /etc/systemd/system/etcd.service.

# confirm
sudo systemctl status etcd --no-pager
# ● etcd.service - etcd
#      Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-05 12:11:45 EDT; 3s ago
#    Main PID: 9101 (etcd)
#       Tasks: 15 (limit: 9328)
#      Memory: 13.3M (peak: 13.3M)
#         CPU: 143ms
#      CGroup: /system.slice/etcd.service

# If startup fails:
sudo journalctl -u etcd -n 30 --no-pager
# debug port
sudo ss -ltnp '( sport = :2379 or sport = :2380 )'
```

## Verify mTLS

```sh
ETCD_IP=172.27.224.217

etcdctl --endpoints="https://${ETCD_IP}:2379" \
  --cacert="$HOME/cert/ca/ca.crt"   \
  --cert="$HOME/cert/etcd/apiserver-etcd-client.crt"  \
  --key="$HOME/cert/etcd/apiserver-etcd-client.key" \
  endpoint health
# https://172.27.224.217:2379 is healthy: successfully committed proposal: took = 12.06477ms

etcdctl --endpoints="https://${ETCD_IP}:2379" \
    --cacert="$HOME/cert/ca/ca.crt"  \
    --cert="$HOME/cert/etcd/apiserver-etcd-client.crt" \
    --key="$HOME/cert/etcd/apiserver-etcd-client.key"  \
    put /lab/test hello
# OK

etcdctl --endpoints="https://${ETCD_IP}:2379" \
    --cacert="$HOME/cert/ca/ca.crt"  \
    --cert="$HOME/cert/etcd/apiserver-etcd-client.crt" \
    --key="$HOME/cert/etcd/apiserver-etcd-client.key"  \
    get /lab/test
# /lab/test
# hello

# No client certificate: must fail (TLS error or timeout).
curl --max-time 5 --cacert "$HOME/cert/ca/ca.crt" "https://${ETCD_IP}:2379/health"
# curl: (56) OpenSSL SSL_read: OpenSSL/3.0.13: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
```
