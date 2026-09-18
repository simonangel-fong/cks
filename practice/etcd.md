# Practices - Etcd

[Back](../README.md)

- [Practices - Etcd](#practices---etcd)
  - [Etcd: encrypted at rest](#etcd-encrypted-at-rest)

---

## Etcd: encrypted at rest

- ref: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#encrypting-your-data

```sh
# Generate the encryption key
head -c 32 /dev/urandom | base64

mkdir /etc/kubernetes/enc
```

```yaml
# vi /etc/kubernetes/enc/enc.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
      - pandas.awesome.bears.example
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: WQ0YkuscHZRMm/8k60ww4cAjuXtpL5KKgN4Vl78Cvhs=
      - identity: {}
```

```sh
# mount encryption config file to the kube-apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# spec:
#   containers:
#   - command:
#     - kube-apiserver
#     - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
#     volumeMounts:
#     - name: enc                           # add this line
#       mountPath: /etc/kubernetes/enc      # add this line
#       readOnly: true                      # add this line
#   volumes:
#   - name: enc                             # add this line
#     hostPath:                             # add this line
#       path: /etc/kubernetes/enc           # add this line
#       type: DirectoryOrCreate             # add this line

# test
kubectl create secret generic secret1 -n default --from-literal=mykey=mydata

ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/default/secret1 | hexdump -C
```
