# Practices - Secret

[Back](../../README.md)

- [Practices - Secret](#practices---secret)
  - [Secret: create \& apply](#secret-create--apply)
  - [Secret: get value](#secret-get-value)
  - [Secret: apply as environment variable](#secret-apply-as-environment-variable)
  - [Secret: Mount Secret as Volume](#secret-mount-secret-as-volume)
  - [Secret (killer A)](#secret-killer-a)
  - [secret(killer A)](#secretkiller-a)

---

- Kubernetes Secrets
  - basics of creating Secrets and mounting them to Pods.
  - various type of secrets
    1. Opaque Secrets.
    2. TLS Secrets
    3. Docker config Secrets

## Secret: create & apply

- task

1. create new ns `ns-secure`
2. create sa `secret-manager`
3. create secret `sec-a1` with `password=admin@234`
4. create secret `sec-a2` with file `/etc/hosts`

- solution

```sh
k create ns ns-secure
k -n ns-secure create sa secret-manager
k -n ns-secure create secret generic sec-a1 --from-literal=key=values
k -n ns-secure create secret generic sec-a2 --from-file=hosts=/etc/hosts

# confirm
k get ns ns-secure
# NAME        STATUS   AGE
# ns-secure   Active   25s

k get sa -n ns-secure
# NAME             AGE
# default          4m43s
# secret-manager   4m43s

k -n ns-secure get secret
# NAME     TYPE     DATA   AGE
# sec-a1   Opaque   1      38s
# sec-a2   Opaque   1      38s

k -n ns-secure get secret sec-a1 -o yaml
# data:
#  key: dmFsdWVz
echo dmFsdWVz | base64 -d; echo
# values

k -n ns-secure get secret sec-a2 -o yaml
# data:
#   hosts: MTI3LjAuMC4xIGxvY2FsaG9zdAoxMjcuMC4xLjEgdWJ1bnR1LW5vZGUKCiMgVGhlIGZvbGxvd2luZyBsaW5lcyBhcmUgZGVzaXJhYmxlIGZvciBJUHY2IGNhcGFibGUgaG9zdHMKOjoxICAgICBpcDYtbG9jYWxob3N0IGlwNi1sb29wYmFjawpmZTAwOjowIGlwNi1sb2NhbG5ldApmZjAwOjowIGlwNi1tY2FzdHByZWZpeApmZjAyOjoxIGlwNi1hbGxub2RlcwpmZjAyOjoyIGlwNi1hbGxyb3V0ZXJzCjE5Mi4xNjguMTAuMTUwICAgY29udHJvbHBsYW5lCjE5Mi4xNjguMTAuMTUwICAgY29udHJvbHBsYW5lCg==

echo MTI3LjAuMC4xIGxvY2FsaG9zdAoxMjcuMC4xLjEgdWJ1bnR1LW5vZGUKCiMgVGhlIGZvbGxvd2luZyBsaW5lcyBhcmUgZGVzaXJhYmxlIGZvciBJUHY2IGNhcGFibGUgaG9zdHMKOjoxICAgICBpcDYtbG9jYWxob3N0IGlwNi1sb29wYmFjawpmZTAwOjowIGlwNi1sb2NhbG5ldApmZjAwOjowIGlwNi1tY2FzdHByZWZpeApmZjAyOjoxIGlwNi1hbGxub2RlcwpmZjAyOjoyIGlwNi1hbGxyb3V0ZXJzCjE5Mi4xNjguMTAuMTUwICAgY29udHJvbHBsYW5lCjE5Mi4xNjguMTAuMTUwICAgY29udHJvbHBsYW5lCg== | base64 -d; echo
# 127.0.0.1 localhost
# 127.0.1.1 ubuntu-node

# # The following lines are desirable for IPv6 capable hosts
# ::1     ip6-localhost ip6-loopback
# fe00::0 ip6-localnet
# ff00::0 ip6-mcastprefix
# ff02::1 ip6-allnodes
# ff02::2 ip6-allrouters
# 192.168.10.150   controlplane
# 192.168.10.150   controlplane

```

---

## Secret: get value

- tasks:

1. get the secret of type opaque that have been created in the ns `one`
2. Create a new file called /opt/ks/one and store the base64-decoded values in that file. each value needs to be stored on a new line.

- setup env

```sh
kubectl create ns one
kubectl -n one create secret generic s1 --from-literal=key=secret
kubectl -n one create secret generic s2 --from-literal=key=admin
```

---

- solution

```sh
k get secret -n one
# NAME   TYPE     DATA   AGE
# s1     Opaque   1      6s
# s2     Opaque   1      6s

k -n one get secret s1 -o yaml
# data:
#   key: c2VjcmV0

echo c2VjcmV0 | base64 -d; echo
# secret

k -n one get secret s2 -o yaml
# data:
#   key: YWRtaW4=

echo YWRtaW4= | base64 -d; echo
# admin

# write answer
sudo mkdir /opt/ks
sudo tee /opt/ks/one <<EOF
secret
admin
EOF

# confirm
cat /opt/ks/one
# secrets
# admin
```

- optional

```sh
k -n one get secret -o jsonpath {.data.data}
```

---

## Secret: apply as environment variable

- task:
  - create a secret `secret-1`: `password=admin@123`
  - create a pod named `pod-secret` and apply secret as env var `DB_SECRET`

```sh
# Create a secret
k create secret generic secret-1 --from-literal password=admin@123

# Create Secret as environment variable
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret
spec:
  containers:
  - name: pod-secret
    image: nginx
    env:
    - name: DB_SECRET
      valueFrom:
        secretKeyRef:
          name: secret-1
          key: password
EOF

k exec -it pod-secret -- env | grep DB_SECRET
# DB_SECRET=admin@123
```

---

## Secret: Mount Secret as Volume

- task:
  - create a secret `secret-2`: `password=admin@123`
  - create a pod named `pod-secret-mount` and mount secret `/etc/secret-2/db-pwd`

```sh
# Create a secret
kubectl create secret generic secret-2 --from-literal db-pwd=admin@23

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret-mount
spec:
  containers:
  - name: pod-secret-mount
    image: nginx
    volumeMounts:
    - name: secret-2
      mountPath: "/etc/secret-2"
      readOnly: true
  volumes:
  - name: secret-2
    secret:
      secretName: secret-2
      items:
      - key: db-pwd
        path: db-pwd
EOF

k exec -it pod-secret-mount -- cat /etc/secret-2/db-pwd; echo
# admin@23
```

---

## Secret (killer A)

- task:
  - There is Secret `db-con` in Namespace `team-khaki-us-east-ad1`. Update the `password` to `4c!29f_Ee2e` and ensure all Pods currently using the Secret will work with the updated value.
  - Move Secret `user-data` from Namespace `team-khaki-us-east-ad1` to `team-khaki-us-east-ad2`.
  - Convert ConfigMap `app-data` in Namespace `team-khaki-us-east-ad1` to a Secret and delete the ConfigMap afterwards. Ensure all Pods that used the ConfigMap will continue to work and are now using the values from the Secret.

- setup
  - 2 app using db-con as DB_PASSWORD
    - app-green-sky
    - app-runrise

```sh
# task1

k create secret generic s1 --from-literal=password='4c!29f_Ee2e' --dry-run=client -o yaml
# get the encoded value
k edit secret db-con -n team-khaki-us-east-ad1
# data:
#  password: <encoded_value>

kubectl rollout restart deployment -n team-khaki-us-east-ad1

# task2
kubectl get secret user-data -n team-khaki-us-east-ad1 -o yaml > /tmp/user-data.yaml
vi /tmp/user-data.yaml
# metadata:
#   namespace: team-khaki-us-east-ad2

kubectl apply -f /tmp/user-data.yaml
# confirm
k get secret user-data -n team-khaki-us-east-ad2
kubectl delete secret user-data -n team-khaki-us-east-ad1


# task3
kubectl get cm app-data -n team-khaki-us-east-ad1 -o yaml > /tmp/app-data-secret.yaml

vi /tmp/app-data-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-data
  namespace: team-khaki-us-east-ad1
type: Opaque
stringData:
  app.interface.properties: |
    load=lazy3
    loader=lazy3.v3.loader
    allow.renew=true
    allow.pass=c395e8d2
  interface_file_name: app.interface.properties
  token: c395e8d2-2525-4621-a99e-9bf111f4caeb
```

```sh
kubectl apply -f /tmp/app-data-secret.yaml

# update deployment: from cm to secret
```

---

## secret(killer A)

- task:
  Namespace security contains five Secrets of type Opaque which can be considered highly confidential. The latest Incident-Prevention-Investigation revealed that ServiceAccount p.auster had too broad access to the cluster for some time. This SA should never have had access to any Secrets in that Namespace.
  Find out which Secrets in Namespace security this SA accessed by looking at the Audit Logs under /course/p2/audit.log.
  For only those Secrets that were accessed by this SA, change their password to any new string.
  ℹ️ You can use jq to render JSON in a more readable form, for example cat data.json | jq

---

- solution:

```sh
# get secrets
k -n security get secrets
# postgresql1
# postgresql2
# mysql1
# mysql2
# vault1

# lookup each secret in log
cat /course/p2/audit.log | grep postgresql1
# none

cat /course/p2/audit.log | grep postgresql2
# none

cat /course/p2/audit.log | grep mysql1
# show request records
cat /course/p2/audit.log | grep mysql1 | grep p.auster
# show p.auster request

cat /course/p2/audit.log | grep mysql2
# none

cat /course/p2/audit.log | grep vault1
# show request records
cat /course/p2/audit.log | grep vault1 | grep p.auster
# show p.auster request

k edit secret mysql1
k edit secret vault1
```
