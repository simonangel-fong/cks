# CKS: `kube-apiserver` - Encryption at rest

[Back](../README.md)

- [CKS: `kube-apiserver` - Encryption at rest](#cks-kube-apiserver---encryption-at-rest)
  - [Secure data storage at rest](#secure-data-storage-at-rest)
    - [Encryption providers](#encryption-providers)
  - [Lab: plain text at rest](#lab-plain-text-at-rest)
  - [Lab: Encrypt at rest](#lab-encrypt-at-rest)

---

## Secure data storage at rest

- By defautl, `etcd` stores data **in plain text.**
  - sensitive data, e.g., secrets, can be read directly from the disk.
- can associate an encryption key at `kube-apiserver` level
  - the data can be encrypted **before being stored** at the ETCD.

- `apiserver` flag:
  - `--encryption-provider-config`: spcecify encryption providers to be used for storing secrets in etcd

- ref: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

---

### Encryption providers

| Encryption Providers | Encryption                      | Strength  | Speed  |
| -------------------- | ------------------------------- | --------- | ------ |
| Identity             | None                            | N/A       | N/A    |
| aescbc               | AES-CBC with PKCS#7 padding     | Strongest | Fast   |
| secretbox            | XSalsa20 and Poly1305           | Strong    | Faster |
| kms                  | Uses envelope encryption scheme | Strongest | Fast   |

- By default, the `identity` provider is used to protect secrets in etcd
  - provides no encryption.
- can make use of KMS provider for additional security.
- the **older secrets** would still be in an **unencrypted form**.

---

## Lab: plain text at rest

```sh
cat /etc/systemd/system/kube-apiserver.service | grep etcd
  # --etcd-servers=https://127.0.0.1:2379 \
  # --etcd-cafile=/etc/kubernetes/pki/ca.crt \
  # --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  # --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \

# ##############################
# create admin user
# ##############################
mkdir -pv ~/cks/pki
cd ~/cks/pki

# create private key
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr

sudo openssl x509 -req -in admin.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out admin.crt -days 1000
# Certificate request self-signature ok
# subject=CN = admin, O = system:masters

sudo kubectl get secret --server=https://127.0.0.1:6443 --client-certificate admin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key admin.key
# No resources found in default namespace.

# ##############################
# create secret
# ##############################
sudo kubectl create secret generic new-secret -n default --from-literal=user=secretpassword --server=https://127.0.0.1:6443 --client-certificate admin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key admin.key
# secret/new-secret created

# confirm
sudo kubectl get secret new-secret -n default --server https://127.0.0.1:6443 --client-certificate admin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key admin.key
# NAME         TYPE     DATA   AGE
# new-secret   Opaque   1      84s

# ##############################
# view plain text
# ##############################
# get ca
systemctl status etcd --no-page | grep load
    #  Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)

cat /etc/systemd/system/etcd.service | grep -E "trusted-ca-file"
  # --trusted-ca-file=/etc/kubernetes/pki/ca.crt \

# etcd client cert: apiserver
systemctl status kube-apiserver --no-page | grep load
    #  Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)

cat /etc/systemd/system/kube-apiserver.service | grep etcd
  # --etcd-servers=https://127.0.0.1:2379 \
  # --etcd-cafile=/etc/kubernetes/pki/ca.crt \
  # --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  # --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \

# decode value:  value secretpassword is visible
ETCDCTL_API=3 sudo etcdctl    \
  --endpoints=https://127.0.0.1:2379    \
  --insecure-skip-tls-verify            \
  --insecure-transport=false            \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt    \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key     \
  get /registry/secrets/default/new-secret | hexdump -C
# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# 00000010  73 2f 64 65 66 61 75 6c  74 2f 6e 65 77 2d 73 65  |s/default/new-se|
# 00000020  63 72 65 74 0a 6b 38 73  00 0a 0c 0a 02 76 31 12  |cret.k8s.....v1.|
# 00000030  06 53 65 63 72 65 74 12  d4 01 0a b1 01 0a 0a 6e  |.Secret........n|
# 00000040  65 77 2d 73 65 63 72 65  74 12 00 1a 07 64 65 66  |ew-secret....def|
# 00000050  61 75 6c 74 22 00 2a 24  36 61 39 34 33 62 35 63  |ault".*$6a943b5c|
# 00000060  2d 33 65 32 66 2d 34 34  37 65 2d 38 66 36 63 2d  |-3e2f-447e-8f6c-|
# 00000070  33 37 36 65 31 62 65 62  36 33 35 32 32 00 38 00  |376e1beb63522.8.|
# 00000080  42 08 08 f0 f1 f2 d4 06  10 00 8a 01 61 0a 0e 6b  |B...........a..k|
# 00000090  75 62 65 63 74 6c 2d 63  72 65 61 74 65 12 06 55  |ubectl-create..U|
# 000000a0  70 64 61 74 65 1a 02 76  31 22 08 08 f0 f1 f2 d4  |pdate..v1"......|
# 000000b0  06 10 00 32 08 46 69 65  6c 64 73 56 31 3a 2d 0a  |...2.FieldsV1:-.|
# 000000c0  2b 7b 22 66 3a 64 61 74  61 22 3a 7b 22 2e 22 3a  |+{"f:data":{".":|
# 000000d0  7b 7d 2c 22 66 3a 75 73  65 72 22 3a 7b 7d 7d 2c  |{},"f:user":{}},|
# 000000e0  22 66 3a 74 79 70 65 22  3a 7b 7d 7d 42 00 12 16  |"f:type":{}}B...|
# 000000f0  0a 04 75 73 65 72 12 0e  73 65 63 72 65 74 70 61  |..user..secretpa|
# 00000100  73 73 77 6f 72 64 1a 06  4f 70 61 71 75 65 1a 00  |ssword..Opaque..|
# 00000110  22 00 0a                                          |"..|
# 00000113

# ##############################
# search value on disk
# ##############################
# data dir
cat /etc/systemd/system/etcd.service | grep data-dir
  # --data-dir=/var/lib/etcd \

sudo grep -R "secretpassword" /var/lib/etcd
# grep: /var/lib/etcd/member/snap/db: binary file matches
# grep: /var/lib/etcd/member/wal/0000000000000000-0000000000000000.wal: binary file matches
```

---

## Lab: Encrypt at rest

```sh
# create encrypt key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY
# x/W1OeiSqlgN9M85MhaQX5hq8HfH5PEuTr/+fMtuz7o=

# create manifest dir
sudo mkdir -pv /var/lib/kubernetes
# mkdir: created directory '/var/lib/kubernetes'

# create manifest
sudo tee /var/lib/kubernetes/encryption-at-rest.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

sudo vim /etc/systemd/system/kube-apiserver.service
# add flag
# --encryption-provider-config=/var/lib/kubernetes/encryption-at-rest.yaml

sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver
systemctl status kube-apiserver | grep Active
    #  Active: active (running) since Sat 2026-09-05 20:56:41 EDT; 22s ago



# create new secret
sudo kubectl create secret generic db-secret -n default --from-literal=dbadmin=dbpasswd --server https://127.0.0.1:6443 --client-certificate admin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key admin.key
# secret/db-secret created

# confirm
sudo kubectl get secret --server https://127.0.0.1:6443 --client-certificate admin.crt --certificate-authority /etc/kubernetes/pki/ca.crt --client-key admin.key
# NAME         TYPE     DATA   AGE
# db-secret    Opaque   1      29s
# new-secret   Opaque   1      9m2s

# decode value: invisible
ETCDCTL_API=3 sudo etcdctl    \
  --endpoints=https://127.0.0.1:2379    \
  --insecure-skip-tls-verify            \
  --insecure-transport=false            \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt    \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key     \
  get /registry/secrets/default/db-secret | hexdump -C

# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# 00000010  73 2f 64 65 66 61 75 6c  74 2f 64 62 2d 73 65 63  |s/default/db-sec|
# 00000020  72 65 74 0a 6b 38 73 3a  65 6e 63 3a 61 65 73 63  |ret.k8s:enc:aesc|
# 00000030  62 63 3a 76 31 3a 6b 65  79 31 3a b1 a9 ed 37 97  |bc:v1:key1:...7.|
# 00000040  14 8f c7 a3 32 9a b5 b0  23 b3 64 d7 c9 2b 23 0b  |....2...#.d..+#.|
# 00000050  eb 5b b7 23 da ee e4 f6  64 0f 5d ea 09 62 a7 8f  |.[.#....d.]..b..|
# 00000060  d8 fe 03 c5 2a f5 78 9e  26 ba 17 8c 4a 46 96 61  |....*.x.&...JF.a|
# 00000070  a6 78 40 5f 79 1a 51 eb  c7 6d 13 d5 16 d6 2a fa  |.x@_y.Q..m....*.|
# 00000080  83 51 a5 8a 33 5c 0a 3f  6c 0f 06 b8 6c 75 e5 7b  |.Q..3\.?l...lu.{|
# 00000090  4e d4 0d 46 5e 7c e3 31  c3 4a 08 13 51 a9 b4 5f  |N..F^|.1.J..Q.._|
# 000000a0  f9 89 6e e4 a9 cc 1b 75  0a 1e f9 af 78 8b 48 c8  |..n....u....x.H.|
# 000000b0  af 7e dc 54 4d 84 46 ba  bc 9d f0 6d a8 e0 7e ec  |.~.TM.F....m..~.|
# 000000c0  6a 55 e8 6e 09 d4 e3 19  e7 b5 50 49 4c 75 5f 05  |jU.n......PILu_.|
# 000000d0  65 d6 70 40 fa 49 68 42  c2 a2 79 1b c3 ab 28 ec  |e.p@.IhB..y...(.|
# 000000e0  19 37 c1 c5 a7 40 a8 0a  2a a3 12 ac 46 23 7e 06  |.7...@..*...F#~.|
# 000000f0  8c 80 a2 20 45 5f c7 50  e1 03 02 36 1a c6 c6 bd  |... E_.P...6....|
# 00000100  10 e9 5f 20 6f 98 e0 3c  12 e8 51 df 12 bf 7a 9d  |.._ o..<..Q...z.|
# 00000110  64 d0 f5 ab 82 ec 5f 87  04 d9 b3 48 ad 8b fc 01  |d....._....H....|
# 00000120  3d 18 eb f5 64 4f 60 63  a5 b5 86 ee e5 8f 70 0d  |=...dO`c......p.|
# 00000130  47 26 e4 3f 05 12 07 67  5c 28 77 0a              |G&.?...g\(w.|

# ##############################
# search value on disk
# ##############################
grep -R "dbpasswd" /var/lib/etcd
# return none

# ##############################
# confirm: old entry still unencrypted
# ##############################
sudo grep -R "new-secret" /var/lib/etcd
# grep: /var/lib/etcd/member/snap/db: binary file matches
# grep: /var/lib/etcd/member/wal/0000000000000000-0000000000000000.wal: binary file matches
```
