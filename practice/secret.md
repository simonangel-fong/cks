# Practices - Secret

[Back](../README.md)

- [Practices - Secret](#practices---secret)
  - [Secret](#secret)
  - [Secret: environment variable](#secret-environment-variable)
  - [Secret: Mount Secret as Volume](#secret-mount-secret-as-volume)

---

- Kubernetes Secrets
  - basics of creating Secrets and mounting them to Pods.
  - various type of secrets
    1. Opaque Secrets.
    2. TLS Secrets
    3. Docker config Secrets

## Secret

- question

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

## Secret: environment variable

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
