# Practices - `etcd`

[Back](../../README.md)

- [Practices - `etcd`](#practices---etcd)
  - [`etcd`: encrypted at rest](#etcd-encrypted-at-rest)
  - [etcd: encrypted at rest(killer A)](#etcd-encrypted-at-restkiller-a)
  - [etcd: query(killer B)](#etcd-querykiller-b)

---

## `etcd`: encrypted at rest

- ref: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#encrypting-your-data

- task:
  - encrypt the `etcd` at rest

---

- solution:

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

---

## etcd: encrypted at rest(killer A)

- task:
  - An internal security audit requires secrets in the cluster to be encrypted. The team already created the needed EncryptionConfiguration at `/etc/kubernetes/etcd/ec.yaml`.
  - The Apiserver should mount `/etc/kubernetes/etcd` on the host to `/etc/kubernetes/etcd` inside the container
  - The Apiserver should use the EncryptionConfiguration from `/etc/kubernetes/etcd/ec.yaml` inside the container
  - All Secrets in Namespace team-magenta should be stored encrypted in ETCD

---

- solution:

```sh
sudo -i

vi /etc/kubernetes/manifests/kube-apiserver.yaml
#  - --encryption-provider-config=/etc/kubernetes/etcd/ec.yaml

#     volumeMounts:
#     - name: enc
#       mountPath: /etc/kubernetes/etcd
#       readOnly: true
#   volumes:
#   - name: enc
#     hostPath:
#       path: /etc/kubernetes/etcd
#       type: DirectoryOrCreate

# confimr apiserver
crictl ps | grep apiserver

kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

---

## etcd: query(killer B)

- task:
  - There is an existing Secret called `database-access` in Namespace `team-daisy`.
  - Read the complete Secret content directly from `ETCD` (using `etcdctl`) and store it into `/course/11/etcd-secret-content`
  - Write the plain decoded value of the Secret's key pass into `/course/11/database-password`
  - ℹ️ Use sudo -i to become root which may be required for this question

---

- solution:

```sh
ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/team-daisy/database-access > /course/11/etcd-secret-content

k -n team-daisy get secret database-access -o yaml
echo encode_value | base64 -d > /course/11/database-password
```
