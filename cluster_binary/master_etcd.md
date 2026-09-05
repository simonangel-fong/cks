# CKS - Master node: `etcd`

[Back](../../index.md)

- [CKS - Master node: `etcd`](#cks---master-node-etcd)
  - [PKI](#pki)
    - [Create Root CA](#create-root-ca)
    - [Install CA certificates](#install-ca-certificates)
    - [Create `etcd` certificates](#create-etcd-certificates)
    - [Install `etcd` certificates](#install-etcd-certificates)
  - [Install `etcd`](#install-etcd)
    - [Required files and ports](#required-files-and-ports)

---

## PKI

### Create Root CA

```sh
mkdir -pv ~/pki
# mkdir: created directory '/home/ubuntuadmin/pki'

cd ~/pki

# ##############################
# Configure Root CA
# ##############################
# generate CA private key
openssl genrsa -out ca.key 2048

# self-signed CA cert
openssl req -x509 -new -noenc -key ca.key -sha256 -days 3650 \
  -subj "/CN=kubernetes-ca/O=Kubernetes" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out ca.crt

# confirm
openssl x509 -in ca.crt -noout -subject -ext basicConstraints
# subject=CN = kubernetes-ca, O = Kubernetes
# X509v3 Basic Constraints: critical
#     CA:TRUE

ls ca.*
# ca.crt  ca.key
```

---

### Install CA certificates

```sh
# create default path for Public Key Infrastructure (PKI) certificates and private keys
sudo mkdir -pv /etc/kubernetes/pki
# mkdir: created directory '/etc/kubernetes'
# mkdir: created directory '/etc/kubernetes/pki'

cd ~/pki

# root ca
sudo install -v -m 644 ca.crt /etc/kubernetes/pki/ca.crt
# 'ca.crt' -> '/etc/kubernetes/pki/ca.crt'
sudo install -v -m 600 ca.key /etc/kubernetes/pki/ca.key
# 'ca.key' -> '/etc/kubernetes/pki/ca.key'

# update ownership
sudo chown -Rv root:root /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key

ls -l /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key
# -rw------- 1 root root 1704 Sep  3 08:29 /etc/kubernetes/pki/ca.key
# -rw-r--r-- 1 root root 1204 Sep  3 08:29 /etc/kubernetes/pki/ca.crt
```

---

### Create `etcd` certificates

```sh
cd ~/pki

# create conf file
cat > etcd-server.conf <<'EOF'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = etcd
O = Kubernetes

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = controlplane
DNS.2 = localhost
IP.1  = 192.168.10.180
IP.2  = 127.0.0.1
EOF

# create private key
openssl genrsa -out etcd-server.key 2048
# create csr with conf
openssl req -new -key etcd-server.key -out etcd-server.csr -config etcd-server.conf
# sign csr with conf
openssl x509 -req -in etcd-server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out etcd-server.crt -days 365 -sha256 \
  -extensions v3_ext -extfile etcd-server.conf

# Certificate request self-signature ok
# subject=CN = etcd, O = Kubernetes

# confirm
openssl x509 -in etcd-server.crt -noout -subject -ext subjectAltName
# subject=CN = etcd, O = Kubernetes
# X509v3 Subject Alternative Name:
#     DNS:controlplane, DNS:localhost, IP Address:192.168.10.180, IP Address:127.0.0.1

ls | grep etcd-server
# etcd-server.conf
# etcd-server.crt
# etcd-server.csr
# etcd-server.key
```

---

### Install `etcd` certificates

```sh
# etcd server
sudo install -v -m 644 etcd-server.crt /etc/kubernetes/pki/etcd-server.crt
# 'etcd-server.crt' -> '/etc/kubernetes/pki/etcd-server.crt'
sudo install -v -m 600 etcd-server.key /etc/kubernetes/pki/etcd-server.key
# 'etcd-server.key' -> '/etc/kubernetes/pki/etcd-server.key'

# update ownership
sudo chown -Rv root:root /etc/kubernetes/pki/etcd-server.crt /etc/kubernetes/pki/etcd-server.key
# ownership of '/etc/kubernetes/pki/etcd-server.crt' retained as root:root
# ownership of '/etc/kubernetes/pki/etcd-server.key' retained as root:root

ls -l /etc/kubernetes/pki/etcd-server.crt /etc/kubernetes/pki/etcd-server.key
# -rw-r--r-- 1 root root 1294 Sep  3 08:26 /etc/kubernetes/pki/etcd-server.crt
# -rw------- 1 root root 1704 Sep  3 08:26 /etc/kubernetes/pki/etcd-server.key
```

---

## Install `etcd`

### Required files and ports

| Requirement                                   | Type               | Purpose                          |
| --------------------------------------------- | ------------------ | -------------------------------- |
| `/etc/kubernetes/pki/ca.crt`                  | CA certificate     | Verifies TLS certificates        |
| `/etc/kubernetes/pki/etcd-server.crt`         | Server certificate | Identifies the etcd server       |
| `/etc/kubernetes/pki/etcd-server.key`         | Private key        | Private key for the server certificate |
| `192.168.10.180:2379`                         | Client endpoint    | Receives etcd client requests    |
| `192.168.10.180:2380`                         | Peer endpoint      | Handles etcd peer communication  |

```sh
# version
export ETCD_VERSION=v3.6.14

# ##############################
# Download etcd
# ##############################
cd /tmp
curl -fLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
#   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
# 100 22.5M  100 22.5M    0     0  20.2M      0  0:00:01  0:00:01 --:--:-- 20.2M

tar -xzf "etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
sudo install -v -m 755 "etcd-${ETCD_VERSION}-linux-amd64/etcd" "etcd-${ETCD_VERSION}-linux-amd64/etcdctl" /usr/local/bin/
# 'etcd-v3.6.14-linux-amd64/etcd' -> '/usr/local/bin/etcd'
# 'etcd-v3.6.14-linux-amd64/etcdctl' -> '/usr/local/bin/etcdctl'

etcd --version
# etcd Version: 3.6.14
# Go OS/Arch: linux/amd64

etcdctl version
# etcdctl version: 3.6.14
# API version: 3.6

# ##############################
# Configure systemd unit: etcd
# ##############################
cat <<'EOF' | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name controlplane \
  --advertise-client-urls https://192.168.10.180:2379 \
  --trusted-ca-file=/etc/kubernetes/pki/ca.crt \
  --cert-file=/etc/kubernetes/pki/etcd-server.crt \
  --data-dir=/var/lib/etcd \
  --key-file=/etc/kubernetes/pki/etcd-server.key \
  --peer-cert-file=/etc/kubernetes/pki/etcd-server.crt \
  --peer-key-file=/etc/kubernetes/pki/etcd-server.key \
  --peer-trusted-ca-file=/etc/kubernetes/pki/ca.crt \
  --client-cert-auth \
  --peer-client-cert-auth \
  --initial-advertise-peer-urls https://192.168.10.180:2380 \
  --listen-peer-urls https://192.168.10.180:2380 \
  --listen-client-urls https://192.168.10.180:2379,https://127.0.0.1:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster controlplane=https://192.168.10.180:2380 \
  --initial-cluster-state new
Restart=on-failure
RestartSec=5
LimitNOFILE=40000

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
#      Active: active (running) since Thu 2026-09-03 08:37:34 EDT; 5s ago
#        Docs: https://github.com/etcd-io/etcd
#    Main PID: 2871 (etcd)
#       Tasks: 7 (limit: 3179)
#      Memory: 7.9M (peak: 7.9M)
#         CPU: 71ms
#      CGroup: /system.slice/etcd.service
#              └─2871 /usr/local/bin/etcd --name controlplane --data-dir=/var/lib/etcd --cert-file=/etc/kube…

# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.710974-0400","cal…ests"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.711073-0400","cal….6.0"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.711766-0400","cal…emon"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.711100-0400","cal…ests"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.711821-0400","cal…emon"}
# Sep 03 08:37:34 controlplane systemd[1]: Started etcd.service - etcd.
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.716205-0400","cal…VING"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.717293-0400","cal…VING"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.718094-0400","cal…2379"}
# Sep 03 08:37:34 controlplane etcd[2871]: {"level":"info","ts":"2026-09-03T08:37:34.718719-0400","cal…2379"}
# Hint: Some lines were ellipsized, use -l to show in full.

# test connection
sudo etcdctl member list -w table \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/ca.crt \
  --cert=/etc/kubernetes/pki/etcd-server.crt \
  --key=/etc/kubernetes/pki/etcd-server.key
# +------------------+---------+--------------+-----------------------------+-----------------------------+------------+
# |        ID        | STATUS  |     NAME     |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
# +------------------+---------+--------------+-----------------------------+-----------------------------+------------+
# | 68b8303d1213ddbb | started | controlplane | https://192.168.10.180:2380 | https://192.168.10.180:2379 |      false |
# +------------------+---------+--------------+-----------------------------+-----------------------------+------------+

# health of the endpoint
sudo etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/ca.crt \
  --cert=/etc/kubernetes/pki/etcd-server.crt \
  --key=/etc/kubernetes/pki/etcd-server.key
# https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 6.349056ms
```
