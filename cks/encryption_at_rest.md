# Encryption at rest

- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

### Encryption at rest

etcd stores Secrets base64-encoded, not encrypted. This config encrypts them
on write -- a named CKS objective.

```sh
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat <<EOF | sudo tee /etc/kubernetes/config/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
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

sudo chmod 600 /etc/kubernetes/config/encryption-config.yaml
```

Provider order matters: `aescbc` first means new writes are encrypted;
`identity` last lets already-plaintext values still be read. Note the heredoc
delimiter here is **unquoted** (`<<EOF`) so `${ENCRYPTION_KEY}` expands -- a
quoted `<<'EOF'` writes the literal string and every Secret write then fails.

---

## Confirm encryption at rest

```sh
# sample secret to test
kubectl create secret generic sample-test --from-literal=key=value
# secret/sample-test created

# get from etcd
sudo etcdctl get /registry/secrets/default/sample-test --hex \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/ca.pem \
  --cert=/etc/kubernetes/pki/etcd-server.pem \
  --key=/etc/kubernetes/pki/etcd-server-key.pem | head -5
# \x2f\x72\x65\x67\x69\x73\x74\x72\x79\x2f\x73\x65\x63\x72\x65\x74\x73\x2f\x64\x65\x66\x61\x75\x6c\x74\x2f\x73\x61\x6d\x70\x6c\x65\x2d\x74\x65\x73\x74
# \x6b\x38\x73\x3a\x65\x6e\x63\x3a\x61\x65\x73\x63\x62\x63\x3a\x76\x31\x3a\x6b\x65\x79\x31\x3a\x3f\xd9\x0f\xb0\x38\x25\x81\xca\x8d\xe6\x31\x73\x57\x0f\x23\x8c\x2a\x74\xa7\x2c\xef\xfd\x89\x09\x7e\xf3\x3f\x55\x52\x7b\xad\x39\xe5\xa5\x8d\x73\x7d\xb4\x2d\x59\x04\x66\x0b\xdd\x2a\x7c\x70\xac\x71\x9e\x38\x8b\xaf\x07\x5e\x46\xd7\x65\x8f\x87\xe1\xd0\x10\xdd\x75\x7d\x3c\x59\xda\xe0\x04\xa5\xa1\x35\x7e\xc4\xc3\x6a\xa6\x6b\x00\xfb\x41\x8c\x58\x61\xd3\x80\xbb\x44\xab\xcc\xc3\xa4\x69\x76\xca\x40\x2e\xfc\x91\xdc\x0b\x16\x0a\x2f\x5f\xf6\xbd\x55\xcc\xe9\x1e\x1b\xc5\x06\x2a\xf8\xb7\x85\xd7\xb6\xb3\x84\x27\x21\x07\x6b\xe5\x27\x6a\xcf\x5a\x8b\x5e\xdb\x30\xd9\x8b\x08\xdc\x7a\x33\xe4\x39\x38\x05\xc6\x95\x01\x84\x9b\xb7\x7d\xec\xab\x3a\x40\x8e\x96\x42\x04\xcc\x23\xd5\x52\x03\x2d\xae\x7b\x21\x49\x0c\x64\xf2\x9f\x1a\xad\x44\x5b\xa0\xe2\xcb\x81\x54\x88\xe8\x63\x45\x1c\xdb\x84\x16\xbe\xec\x9f\xa2\x6d\xed\x14\x8b\x71\x2e\x43\xe8\xb8\xd2\x60\x72\xf1\x76\xc9\xb3\x1a\x64\xc0\xba\xf5\x8e\x1e\x02\xa1\xcb\x20\x6f\x73\x26\x86\xc7\xeb\x13\xb2\x13\x39\x27\x62\x7e\x88\xb3\x71\xc5\x6a\x12\xda\xab\xf8\x94\x3c\x31\x1a\xb9\xed\x6f\xc1\xbb\xa0

kubectl delete secret sample-test
# secret "sample-test" deleted from default namespac
```

```sh
# ##############################
# Confirm Secret encryption at rest
# ##############################
kubectl create secret generic test-secret --from-literal=password=supersecret
# secret/test-secret created

sudo etcdctl get /registry/secrets/default/test-secret \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/ca.pem \
  --cert=/etc/kubernetes/pki/etcd-server.pem \
  --key=/etc/kubernetes/pki/etcd-server-key.pem | hexdump -C | head

# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# 00000010  73 2f 64 65 66 61 75 6c  74 2f 74 65 73 74 2d 73  |s/default/test-s|
# 00000020  65 63 72 65 74 0a 6b 38  73 3a 65 6e 63 3a 61 65  |ecret.k8s:enc:ae|
# 00000030  73 63 62 63 3a 76 31 3a  6b 65 79 31 3a 00 49 42  |scbc:v1:key1:.IB|
# 00000040  d6 e4 9f 6e 1e 17 5f 38  e9 d7 ad f5 67 dc d3 f9  |...n.._8....g...|
# 00000050  c4 ab c4 1d fd c4 da 75  5d 9b dd 4c 2d 16 db 11  |.......u]..L-...|
# 00000060  83 92 3d 30 ea ba 19 a6  00 c1 f0 57 8a 30 c3 fb  |..=0.......W.0..|
# 00000070  9e e3 bf c4 79 c2 bb 06  b8 0c a0 8b 03 a6 3e 2d  |....y.........>-|
# 00000080  8a fa b4 7f ad 6c 4f 2c  66 08 a0 bb 1a 50 20 17  |.....lO,f....P .|
# 00000090  9a 82 7d bd a5 ce cf 77  7c 7f 2d 03 3a 9d 8d 2b  |..}....w|.-.:..+|
```
