# CKS - Worker node: Connect to control plane

[Back](../../index.md)

- [CKS - Worker node: Connect to control plane](#cks---worker-node-connect-to-control-plane)
  - [Required files](#required-files)
  - [Identities](#identities)
  - [Prepare credentials on controlplane](#prepare-credentials-on-controlplane)
    - [Create node01 certificate](#create-node01-certificate)
    - [Create kube-proxy certificate](#create-kube-proxy-certificate)
    - [Create kubelet kubeconfig](#create-kubelet-kubeconfig)
    - [Create kube-proxy kubeconfig](#create-kube-proxy-kubeconfig)
  - [Transfer files to node01](#transfer-files-to-node01)
  - [Verify files on node01](#verify-files-on-node01)

---

## Required files

| File              | Purpose                                        |
| ----------------- | ---------------------------------------------- |
| `ca.crt`          | Verifies certificates issued by the cluster CA |
| `node01.crt`      | Identifies the node01 kubelet                  |
| `node01.key`      | Private key for the node01 certificate         |
| `kubelet.conf`    | Connects kubelet to the API server             |
| `kube-proxy.conf` | Connects kube-proxy to the API server          |

## Identities

| Certificate      | CN                   | O                     | Purpose                  |
| ---------------- | -------------------- | --------------------- | ------------------------ |
| `node01.crt`     | `system:node:node01` | `system:nodes`        | Authenticates kubelet    |
| `kube-proxy.crt` | `system:kube-proxy`  | `system:node-proxier` | Authenticates kube-proxy |

---

## Prepare credentials on controlplane

Run this section on `controlplane`.

```sh
mkdir -pv ~/worker-node01
# mkdir: created directory '/home/ubuntuadmin/worker-node01'
cd ~/worker-node01

cp -v ~/pki/ca.crt .
# '/home/ubuntuadmin/pki/ca.crt' -> './ca.crt'
```

### Create node01 certificate

```sh
cat > node01.conf <<'EOF'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = system:node:node01
O = system:nodes

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = node01
IP.1 = 192.168.10.181
EOF

# create private key: node01
openssl genrsa -out node01.key 2048
# create csr: node01
openssl req -new -key node01.key -out node01.csr -config node01.conf

# sign
openssl x509 -req -in node01.csr \
  -CA ~/pki/ca.crt \
  -CAkey ~/pki/ca.key \
  -CAcreateserial \
  -out node01.crt \
  -days 365 \
  -sha256 \
  -extensions v3_ext \
  -extfile node01.conf
# Certificate request self-signature ok
# subject=CN = system:node:node01, O = system:nodes

openssl verify -CAfile ca.crt node01.crt
# node01.crt: OK

openssl x509 -in node01.crt -noout -subject -ext subjectAltName
# subject=CN = system:node:node01, O = system:nodes
# X509v3 Subject Alternative Name:
#     DNS:node01, IP Address:192.168.10.181

rm -fv node01.csr
# removed 'node01.csr'
```

### Create kube-proxy certificate

```sh
cat > client-ext.conf <<'EOF'
[ v3_ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
EOF

# create private key: kube-proxy
openssl genrsa -out kube-proxy.key 2048
# create csr
openssl req -new \
  -key kube-proxy.key \
  -out kube-proxy.csr \
  -subj "/CN=system:kube-proxy/O=system:node-proxier"

# sign
openssl x509 -req -in kube-proxy.csr \
  -CA ~/pki/ca.crt \
  -CAkey ~/pki/ca.key \
  -CAcreateserial \
  -out kube-proxy.crt \
  -days 365 \
  -sha256 \
  -extensions v3_ext \
  -extfile client-ext.conf
# Certificate request self-signature ok
# subject=CN = system:kube-proxy, O = system:node-proxier

# verify crt
openssl verify -CAfile ca.crt kube-proxy.crt
# kube-proxy.crt: OK

openssl x509 -in kube-proxy.crt -noout -subject
# subject=CN = system:kube-proxy, O = system:node-proxier

rm -fv kube-proxy.csr
# removed 'kube-proxy.csr'
```

### Create kubelet kubeconfig

```sh
kubectl config set-cluster kubernetes \
  --server=https://192.168.10.180:6443 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=kubelet.conf
# Cluster "kubernetes" set.


kubectl config set-credentials system:node:node01 \
  --client-certificate=node01.crt \
  --client-key=node01.key \
  --embed-certs=true \
  --kubeconfig=kubelet.conf
# User "system:node:node01" set.

kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:node:node01 \
  --kubeconfig=kubelet.conf

# Context "default" created.

kubectl config use-context default --kubeconfig=kubelet.conf
# Switched to context "default".
```

### Create kube-proxy kubeconfig

```sh
kubectl config set-cluster kubernetes \
  --server=https://192.168.10.180:6443 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=kube-proxy.conf
# Cluster "kubernetes" set.

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.crt \
  --client-key=kube-proxy.key \
  --embed-certs=true \
  --kubeconfig=kube-proxy.conf
# User "system:kube-proxy" set.

kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.conf

# Context "default" created.

kubectl config use-context default --kubeconfig=kube-proxy.conf
# Switched to context "default".
```

---

## Transfer files to node01

Run this section on `controlplane`.

```sh
ssh ubuntuadmin@192.168.10.181 'mkdir -p ~/worker-bootstrap'

scp \
  ca.crt \
  node01.crt \
  node01.key \
  kubelet.conf \
  kube-proxy.conf \
  ubuntuadmin@192.168.10.181:~/worker-bootstrap/
# ca.crt                                                                         100% 1204   770.2KB/s   00:00
# node01.crt                                                                     100% 1285     2.0MB/s   00:00
# node01.key                                                                     100% 1704   409.1KB/s   00:00
# kubelet.conf                                                                   100% 5946     3.4MB/s   00:00
# kube-proxy.conf                                                                100% 5888     5.2MB/s   00:00
```

---

## Verify files on node01

Run this section on `node01`.

```sh
cd ~/worker-bootstrap

ls -l ca.crt node01.crt node01.key kubelet.conf kube-proxy.conf
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin 1204 Sep  3 23:43 ca.crt
# -rw------- 1 ubuntuadmin ubuntuadmin 5946 Sep  3 23:43 kubelet.conf
# -rw------- 1 ubuntuadmin ubuntuadmin 5888 Sep  3 23:43 kube-proxy.conf
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin 1285 Sep  3 23:43 node01.crt
# -rw------- 1 ubuntuadmin ubuntuadmin 1704 Sep  3 23:43 node01.key

openssl verify -CAfile ca.crt node01.crt
# node01.crt: OK

openssl x509 -in node01.crt -noout -subject -ext subjectAltName
# subject=CN = system:node:node01, O = system:nodes
# X509v3 Subject Alternative Name:
#     DNS:node01, IP Address:192.168.10.181
```

---
