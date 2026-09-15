# Practices - Secret

[Back](../README.md)

- [Practices - Secret](#practices---secret)
  - [Secret](#secret)

---

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
