# CKS: Cilium - Layer 4 Policies

[Back](../README.md)

- [CKS: Cilium - Layer 4 Policies](#cks-cilium---layer-4-policies)
  - [Layer 4 Policies](#layer-4-policies)
  - [Lab: Layer 4 Policies](#lab-layer-4-policies)

---

## Layer 4 Policies

- **Layer 4 policy** can be specified _in addition to_ **layer 3** policies or independently.
  - restricts the ability of an endpoint to emit and/or receive packets on a particular **port** using a particular **protocol**.

- If **no layer 4 policy** is specified for an endpoint, the endpoint is allowed to send and receive on **all layer 4 ports** and protocols including `ICMP`.

---

## Lab: Layer 4 Policies

```sh
# create app-target
kubectl run app-target --image=nginx
# pod/app-target created

# create curl-test
kubectl run curl-test --image=alpine/curl -- sleep 3600
# pod/curl-test created

# confirm
kubectl get pods -o wide
# NAME         READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
# app-target   1/1     Running   0          39s   10.0.1.7     node01   <none>           <none>
# curl-test    1/1     Running   0          23s   10.0.1.240   node01   <none>           <none>

cat << EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-80
spec:
  endpointSelector:
    matchLabels:
      run: curl
  egress:
    - toPorts:
      - ports:
        - port: "80"
          protocol: TCP
EOF
# ciliumnetworkpolicy.cilium.io/allow-external-80 created

# confirm incluster
kubectl exec -it curl-test -- ping -c2 10.0.1.7
# PING 10.0.1.7 (10.0.1.7): 56 data bytes
# 64 bytes from 10.0.1.7: seq=0 ttl=63 time=0.131 ms
# 64 bytes from 10.0.1.7: seq=1 ttl=63 time=0.151 ms

# --- 10.0.1.7 ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 0.131/0.141/0.151 ms

kubectl exec -it curl-test -- curl -I 10.0.1.7 
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Wed, 09 Sep 2026 20:20:09 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

kubectl exec -it curl-test -- ping -c2 google.com
# PING google.com (142.250.139.138): 56 data bytes
# 64 bytes from 142.250.139.138: seq=0 ttl=126 time=23.394 ms
# 64 bytes from 142.250.139.138: seq=1 ttl=126 time=19.168 ms

# --- google.com ping statistics ---
# 2 packets transmitted, 2 packets received, 0% packet loss
# round-trip min/avg/max = 19.168/21.281/23.394 ms

kubectl exec -it curl-test -- curl google.com
# HTTP/1.1 301 Moved Permanently
# Location: http://www.google.com/
# Content-Type: text/html; charset=UTF-8
# Content-Security-Policy-Report-Only: object-src 'none';base-uri 'self';script-src 'nonce-175ICAlsbdwjjlkawKqimA' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
# Date: Wed, 09 Sep 2026 20:21:18 GMT
# Expires: Fri, 09 Oct 2026 20:21:18 GMT
# Cache-Control: public, max-age=2592000
# Server: gws
# Content-Length: 219
# X-XSS-Protection: 0
# X-Frame-Options: SAMEORIGIN

# clean up
kubectl delete cnp allow-external-80
# ciliumnetworkpolicy.cilium.io "allow-external-80" deleted

kubectl delete po --all

```
