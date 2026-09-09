# CKS: Cilium - DNS rule

[Back](../README.md)

- [CKS: Cilium - DNS rule](#cks-cilium---dns-rule)
  - [DNS rules](#dns-rules)
  - [Lab: DNS rules](#lab-dns-rules)

---

## DNS rules

- allows DNS resolution for domain

---

## Lab: DNS rules

- only allow query matching dns

```sh
# create curl-test pod
kubectl run curl-test --image=alpine/curl -- sleep 3600
# pod/curl-test created

cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-dns-arguswatchers"
spec:
  endpointSelector: {}
  egress:
  - toPorts:
    - ports:
      - port: "53"
      rules:
        dns:
         - matchName: "arguswatcher.net"
EOF
# ciliumnetworkpolicy.cilium.io/allow-dns-arguswatchers created

kubectl exec -it curl-test -- nslookup google.com
kubectl exec -it curl-test -- nslookup google.com
# Server:         10.96.0.10
# Address:        10.96.0.10:53

# ** server can't find google.com: REFUSED

# ** server can't find google.com: REFUSED

# command terminated with exit code 1

kubectl exec -it curl-test -- nslookup arguswatcher.net
# Server:         10.96.0.10
# Address:        10.96.0.10:53

# Non-authoritative answer:
# Name:   arguswatcher.net
# Address: 172.64.80.1

# Non-authoritative answer:
# Name:   arguswatcher.net
# Address: 2606:4700:130:436c:6f75:6466:6c61:7265

kubectl delete cnp allow-dns-arguswatchers
# ciliumnetworkpolicy.cilium.io "allow-dns-arguswatchers" deleted

kubectl delete pod curl-test
```
