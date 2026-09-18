# Practices - SA

[Back](../README.md)

- [Practices - SA](#practices---sa)
  - [SA: basic](#sa-basic)
  - [SA: apply to pod](#sa-apply-to-pod)
  - [SA: disable token](#sa-disable-token)

---

- Service Account + Projected Volumes
  - Know how to **create** `service accounts` with auto **mounting token** as disabled.
  - Be familiar with mounting volume sources like SA using `Projected Volumes`.

## SA: basic

- task

1. create new ns `ns-secure`
2. create sa `secret-manager`
3. create secret `sec-a1` with any literal content
4. create secret `sec-a2` with any file content like /etc/hosts

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

## SA: apply to pod

- question
- 1. in ns `ns-secure` create pod `secret-manager` with image `httpd:alpine` which uses the sa `secret-manager`
- 2. mount secret `sec-a1` as env var `SEC_A1`
- 3. mount secret `sec-a2` in the read-only under `/etc/sec-a2`

- solution

```yaml
# nano sa-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-manager
  namespace: ns-secure
spec:
  serviceAccountName: secret-manager
  containers:
    - name: mypod
      image: httpd:alpine
      volumeMounts:
        - name: sec-a2
          mountPath: "/etc/sec-a2"
          readOnly: true
      env:
        - name: SEC_A1
          valueFrom:
            secretKeyRef:
              name: sec-a1
              key: key
  volumes:
    - name: sec-a2
      secret:
        secretName: sec-a2
        optional: true
```

```sh
k apply -f sa-pod.yaml
# pod/secret-manager created

# confirm
k describe pod/secret-manager -n ns-secure

k -n ns-secure exec -it secret-manager -- sh
echo $SEC_A1
# values
ls /etc/sec-a2
# hosts
cat /etc/sec-a2/hosts
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

## SA: disable token

- question

1. modify the config file in `/opt/ks/pod-one.yaml` to disable the mounting of the sa token into the pod
2. apply updated manifests to ns one.
3. confirm sa token is not mounted.

- setup env

```sh
mkdir -p /opt/ks
k create ns one
k create sa custom -n one

sudo tee /opt/ks/pod-one.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-one
  namespace: one
spec:
  serviceAccountName: custom
  containers:
  - name: webserver
    image: nginx:latest
    ports:
    - containerPort: 80
EOF

k apply -f /opt/ks/pod-one.yaml
```

---

- solution

```sh
cat /opt/ks/pod-one.yaml

sudo vi /opt/ks/pod-one.yaml
# spec:
#   serviceAccountName: custom
#   automountServiceAccountToken: false

kubectl replace --force -f /opt/ks/pod-one.yaml
# confirm
kubectl exec -it pod/pod-one -n one -- sh
ls /var/run/secrets/kubernetes.io/serviceaccount
# ls: cannot access '/var/run/secrets/kubernetes.io/serviceaccount': No such file or directory
```

---
