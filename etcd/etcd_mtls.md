# CKS: `etcd` - mTLS

[Back](../README.md)

- [CKS: `etcd` - mTLS](#cks-etcd---mtls)
  - [etcd with mTLS](#etcd-with-mtls)
    - [Key flags](#key-flags)
  - [Lab: Secure etcd with certificate](#lab-secure-etcd-with-certificate)
    - [Create etcd certificate](#create-etcd-certificate)
    - [Configure etcd using https](#configure-etcd-using-https)
  - [Lab: mTLS with etcd and etcdctl](#lab-mtls-with-etcd-and-etcdctl)
    - [Download etcd](#download-etcd)
    - [Create CA](#create-ca)
    - [Create server certificate - etcd certificate](#create-server-certificate---etcd-certificate)
    - [Create client certificate - etcdctl certificate](#create-client-certificate---etcdctl-certificate)
    - [Apply certificates](#apply-certificates)

---

## etcd with mTLS

- By default,
  - `etcd` communicates in plain text
    - can be captured with `tcpdump`.
  - Authentication is not required 
    - anyone with access to the endpoint can query the `etcd` database.
- With `mutual TLS` (`mTLS`), 
  - both the client and server present certificates to authenticate each other.
  - `TLS` encryption protects traffic in transit.

---

### Key flags

| Component        | Flags                             | Purpose                                                |
| ---------------- | --------------------------------- | ------------------------------------------------------ |
| `etcd`           | `--trusted-ca-file`               | `CA` used to verify client certificates                 |
| `etcd`           | `--cert-file`, `--key-file`        | Server certificate and private key                     |
| `etcd`           | `--client-cert-auth=true`         | Require client certificate authentication              |
| `kube-apiserver` | `--etcd-cafile`                   | `CA` used to verify the `etcd` server certificate        |
| `kube-apiserver` | `--etcd-certfile`, `--etcd-keyfile` | Client certificate and private key presented to `etcd` |

## Lab: Secure etcd with certificate

### Create etcd certificate

```sh
mkdir -pv ~/cert/etcd/
# mkdir: created directory '/home/ubuntuadmin/cert/etcd/'
cd ~/cert/etcd

# ##############################
# create etcd key and csr
# ##############################
# create private key
openssl genrsa -out etcd.key 2048

# create csr config file
cat > etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 192.168.10.180
IP.2 = 127.0.0.1
EOF


ls etcd.cnf
# etcd.cnf

# create csr
openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr -config etcd.cnf

# ##############################
# sign csr
# ##############################
openssl x509 -req -in etcd.csr -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -CAcreateserial -out etcd.crt -extensions v3_req -extfile etcd.cnf -days 2000
# Certificate request self-signature ok
# subject=CN = etcd

# confirm
ll ~/cert/etcd
# rwxr-xr-x 2 ubuntuadmin ubuntuadmin 4096 Sep  4 21:59 ./
# drwxr-xr-x 5 ubuntuadmin ubuntuadmin 4096 Sep  4 21:51 ../
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin  278 Sep  4 21:58 etcd.cnf
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin 1196 Sep  4 22:01 etcd.crt
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin  972 Sep  4 22:00 etcd.csr
# -rw------- 1 ubuntuadmin ubuntuadmin 1704 Sep  4 21:52 etcd.key

openssl x509 -in etcd.crt -text -noout | grep -E "Issuer:|Subject:"
        # Issuer: CN = KUBERNETES-CA
        # Subject: CN = etcd

openssl verify -CAfile ~/cert/ca/ca.crt etcd.crt
# etcd.crt: OK
```

---

### Configure etcd using https

- `--cert-file` specifies the path to the `TLS` certificate file.
- `--key-file` specifies the path to the certificate's private key.
- `--advertise-client-urls` specifies the URLs advertised to clients, such as `https://ip:2379`.
- `--listen-client-urls` specifies the URLs on which `etcd` listens for client requests, such as `https://0.0.0.0:2379`.

```sh
export ETCD_VERSION=v3.6.14
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

# apply cert and key, specify https endpoint
./etcd --cert-file=/home/ubuntuadmin/cert/etcd/etcd.crt   \
  --key-file=/home/ubuntuadmin/cert/etcd/etcd.key  \
  --advertise-client-urls=https://127.0.0.1:2379  \
  --listen-client-urls=https://127.0.0.1:2379

# confirm
# without crt
./etcdctl put course "cks"
# {"level":"warn","ts":"2026-09-04T22:10:46.029225-0400","logger":"etcd-client","caller":"v3@v3.6.14/retry_interceptor.go:68","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0002f0b40/127.0.0.1:2379","peer":"Peer{Addr: <nil>, LocalAddr: <nil>, AuthInfo: <nil>}","method":"/etcdserverpb.KV/Put","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: connection error: desc = \"error reading server preface: EOF\""}
# Error: context deadline exceeded

# Enable https
./etcdctl --endpoints=https://127.0.0.1:2379 --insecure-skip-tls-verify --insecure-transport=false put course "cks"
# OK

# confirm
./etcdctl --endpoints=https://127.0.0.1:2379 --insecure-skip-tls-verify --insecure-transport=false get course
# course
# cks


```

## Lab: mTLS with etcd and etcdctl

### Download etcd

```sh
cd /tmp
export ETCD_VERSION=v3.6.14
curl -fLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"

tar -xzf "etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

# Confirm that both binaries are available.
./etcd --version
# etcd Version: 3.6.14
# Git SHA: fc04cf7
# Go Version: go1.25.12
# Go OS/Arch: linux/amd64

./etcdctl version
# etcdctl version: 3.6.14
# API version: 3.6
```

### Create CA

```sh
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

# Store the lab certificates in the current directory.
mkdir -p certs

# Create the CA's private key.
openssl genrsa -out certs/ca.key 2048

# Create a self-signed CA certificate that can sign other certificates.
openssl req -new -x509 -sha256 -days 365 \
  -key certs/ca.key \
  -subj "/CN=etcd-lab-ca" \
  -out certs/ca.crt

# Inspect the CA certificate.
openssl x509 -in certs/ca.crt -text -noout | grep -E "Issuer:|Subject:"
        # Issuer: CN = etcd-lab-ca
        # Subject: CN = etcd-lab-ca

```

### Create server certificate - etcd certificate

```sh
# Create the server's private key.
openssl genrsa -out certs/etcd.key 2048

# Create the server's certificate signing request (CSR).
openssl req -new -key certs/etcd.key -subj "/CN=etcd-server" -out certs/etcd.csr

# Define the certificate's purpose and permitted server addresses.
cat > certs/etcd.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF

# Sign the server certificate with the CA.
openssl x509 -req -sha256 -days 365 \
  -in certs/etcd.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -extfile certs/etcd.ext -out certs/etcd.crt

# Certificate request self-signature ok
# subject=CN = etcd-server

# Verify the certificate's trust, purpose, and IP address.
openssl verify -CAfile certs/ca.crt -purpose sslserver -verify_ip 127.0.0.1 certs/etcd.crt
openssl verify -CAfile certs/ca.crt -purpose sslclient certs/etcd.crt
# certs/etcd.crt: OK

openssl x509 -in certs/etcd.crt -text -noout | grep -E "Issuer:|Subject:"
        # Issuer: CN = etcd-lab-ca
        # Subject: CN = etcd-server
```

---

### Create client certificate - etcdctl certificate

```sh
# Create the client's private key.
openssl genrsa -out certs/etcdctl.key 2048

# Create the client's CSR.
openssl req -new -key certs/etcdctl.key -subj "/CN=etcdctl-client" -out certs/etcdctl.csr

# Define the certificate's client authentication purpose.
cat > certs/etcdctl.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
EOF

# Sign the client certificate using the same CA.
openssl x509 -req -sha256 -days 365 \
  -in certs/etcdctl.csr \
  -CA certs/ca.crt -CAkey certs/ca.key -CAserial certs/ca.srl \
  -extfile certs/etcdctl.ext -out certs/etcdctl.crt

# Certificate request self-signature ok
# subject=CN = etcdctl-client

# Verify the certificate's trust and client authentication purpose.
openssl verify -CAfile certs/ca.crt -purpose sslclient certs/etcdctl.crt
# certs/etcdctl.crt: OK

openssl x509 -in certs/etcdctl.crt -text -noout | grep -E "Issuer:|Subject:"
        # Issuer: CN = etcd-lab-ca
        # Subject: CN = etcdctl-client
```

---

### Apply certificates

- In the first terminal, start `etcd` in the foreground.

```sh

./etcd \
  --name=mtls-lab \
  --advertise-client-urls=https://127.0.0.1:2379 \
  --listen-client-urls=https://127.0.0.1:2379 \
  --client-cert-auth=true \
  --trusted-ca-file=certs/ca.crt \
  --cert-file=certs/etcd.crt \
  --key-file=certs/etcd.key
```

- `--trusted-ca-file` identifies the `CA` that `etcd` trusts to sign client certificates.
- `--cert-file` and `--key-file` configure the server's identity.
- `--client-cert-auth=true` enables client certificate authentication, requiring clients to present a valid certificate signed by the trusted `CA`.

---

- In a second terminal, configure `etcdctl` and test the connection:

```sh
export ETCD_VERSION=v3.6.14
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

# Confirm that the endpoint is healthy.
./etcdctl --endpoints=https://127.0.0.1:2379 --cacert=certs/ca.crt --cert=certs/etcdctl.crt --key=certs/etcdctl.key endpoint health
# 127.0.0.1:2379 is healthy: successfully committed proposal: took = 9.633138ms

# mTLS fails without ca, cert, key
./etcdctl put /lab/mtls "hello-mtls"
# {"level":"warn","ts":"2026-09-04T23:28:54.905772-0400","logger":"etcd-client","caller":"v3@v3.6.14/retry_interceptor.go:68","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc00030a960/127.0.0.1:2379","peer":"Peer{Addr: <nil>, LocalAddr: <nil>, AuthInfo: <nil>}","method":"/etcdserverpb.KV/Put","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: connection error: desc = \"error reading server preface: connection reset by peer\""}
# Error: context deadline exceeded

# success with ca, cert, key
./etcdctl --endpoints=https://127.0.0.1:2379 --cacert=certs/ca.crt --cert=certs/etcdctl.crt --key=certs/etcdctl.key put /lab/mtls "hello-mtls"
# OK

./etcdctl --endpoints=https://127.0.0.1:2379 --cacert=certs/ca.crt --cert=certs/etcdctl.crt --key=certs/etcdctl.key get /lab/mtls
# /lab/mtls
# hello-mtls
```
