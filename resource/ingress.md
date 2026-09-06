# CKS: Ingress

[Back](../README.md)

- [CKS: Ingress](#cks-ingress)
  - [Ingress](#ingress)
    - [Components of Ingress](#components-of-ingress)
  - [TLS](#tls)
    - [SSL direct](#ssl-direct)
  - [Install Nignx ingress](#install-nignx-ingress)
  - [Lab: Ingress with TLS](#lab-ingress-with-tls)
    - [Create workload](#create-workload)
    - [Create secret](#create-secret)
    - [Create ingress](#create-ingress)
    - [redirect](#redirect)

---

## Ingress

- loadbalancer type of service
  - the Load balancer forwards traffic to a `NodePort` associated with a **single service**.
  - limited for multiple services:
    - multiple services = multiple loadbalancers

- `Ingress`
  - acts as an entry point that **routes traffic** to specific `services` based on **rules** you define.
  - a **single** `load balancer` to handle requests for multiple `services`

---

### Components of Ingress

- `Ingress Controller`
  - a specialized software component that **manages external access** to services inside a Kubernetes cluster
  - implements the **route rules** **at runtime**
  - creates load balancer via `service`
    - e.g., `nginx ingress` uses svc **ingress-nginx-controller(LoadBalancer)**
- Ingress Resource

---

## TLS

- secure an `Ingress` by specifying a `Secret` that contains a `TLS private key` and `certificate`.
- by default, assumes TLS **termination at the ingress point**
  - traffic to the `Service` and its `Pods` is **in plaintext**.

- **IMPORTANT**:
  - certificate defined in the TLS secret must contains a `Common Name (CN)` == `Fully Qualified Domain Name (FQDN)`

- example:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: testsecret-tls
  namespace: default
data:
  tls.crt: base64_encoded_cert # cn = fqdn
  tls.key: base64_encoded_key
type: kubernetes.io/tls
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
    - hosts:
        - https-example.foo.com # fqdn
      secretName: testsecret-tls # secret
  rules:
    - host: https-example.foo.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service1
                port:
                  number: 80
```

---

### SSL direct

- By default, the controller **redirects** `HTTP` clients to the `HTTPS` port 443 if **TLS is enabled** for that Ingress.
- Can be disable by ingress annotation:
  - `nginx.ingress.kubernetes.io/ssl-redirect: true`

---

## Install Nignx ingress

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml

kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       2m6s

kubectl get pods -n ingress-nginx
# NAME                                        READY   STATUS    RESTARTS   AGE
# ingress-nginx-controller-7d65c586d6-gdpkv   1/1     Running   0          4m39s

kubectl get service -n ingress-nginx
# NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
# ingress-nginx-controller             LoadBalancer   10.103.247.144   <pending>     80:30344/TCP,443:31178/TCP   4m51s
# ingress-nginx-controller-admission   ClusterIP      10.109.76.127    <none>        443/TCP                      4m51s
```

---

## Lab: Ingress with TLS

### Create workload

```sh
kubectl run ingress-tls --image=nginx
# pod/ingress-tls created

kubectl expose pod ingress-tls --name ingress-tls --port=80 --target-port=80
# service/ingress-tls exposed

kubectl get svc
# NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# ingress-tls   ClusterIP   10.99.87.129   <none>        80/TCP    16s
# kubernetes    ClusterIP   10.96.0.1      <none>        443/TCP   2d18h

kubectl describe svc ingress-tls
# Name:                     ingress-tls
# Namespace:                default
# Labels:                   run=ingress-tls
# Annotations:              <none>
# Selector:                 run=ingress-tls
# Type:                     ClusterIP
# IP Family Policy:         SingleStack
# IP Families:              IPv4
# IP:                       10.99.87.129
# IPs:                      10.99.87.129
# Port:                     <unset>  80/TCP
# TargetPort:               80/TCP
# Endpoints:                10.244.196.138:80
# Session Affinity:         None
# Internal Traffic Policy:  Cluster
# Events:                   <none>

# test
# self-signed cert is used: CN=Kubernetes Ingress Controller Fake Certificate
curl -kv https://192.168.10.180:31178
# *   Trying 192.168.10.180:31178...
# * Connected to 192.168.10.180 (192.168.10.180) port 31178
# * ALPN: curl offers h2,http/1.1
# * TLSv1.3 (OUT), TLS handshake, Client hello (1):
# * TLSv1.3 (IN), TLS handshake, Server hello (2):
# * TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
# * TLSv1.3 (IN), TLS handshake, Certificate (11):
# * TLSv1.3 (IN), TLS handshake, CERT verify (15):
# * TLSv1.3 (IN), TLS handshake, Finished (20):
# * TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
# * TLSv1.3 (OUT), TLS handshake, Finished (20):
# * SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / RSASSA-PSS
# * ALPN: server accepted h2
# * Server certificate:
# *  subject: O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate
# *  start date: Sep  6 20:45:38 2026 GMT
# *  expire date: Sep  6 20:45:38 2027 GMT
# *  issuer: O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate
# *  SSL certificate verify result: self-signed certificate (18), continuing anyway.
# *   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
# * using HTTP/2
# * [HTTP/2] [1] OPENED stream for https://192.168.10.180:31178/
# * [HTTP/2] [1] [:method: GET]
# * [HTTP/2] [1] [:scheme: https]
# * [HTTP/2] [1] [:authority: 192.168.10.180:31178]
# * [HTTP/2] [1] [:path: /]
# * [HTTP/2] [1] [user-agent: curl/8.5.0]
# * [HTTP/2] [1] [accept: */*]
# > GET / HTTP/2
# > Host: 192.168.10.180:31178
# > User-Agent: curl/8.5.0
# > Accept: */*
# >
# * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
# * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
# * old SSL session ID is stale, removing
# < HTTP/2 404
# < date: Sun, 06 Sep 2026 21:25:07 GMT
# < content-type: text/html
# < content-length: 146
# < strict-transport-security: max-age=31536000; includeSubDomains
# <
# <html>
# <head><title>404 Not Found</title></head>
# <body>
# <center><h1>404 Not Found</h1></center>
# <hr><center>nginx</center>
# </body>
# </html>
# * Connection #0 to host 192.168.10.180 left intact
```

### Create secret

```sh
mkdir -pv ~/cks/ingress
cd ~/cks/ingress

# create cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress.key -out ingress.crt -subj "/CN=example.internal/O=security"

ls
# ingress.crt  ingress.key

# create secret
kubectl create secret tls ingress-tls --key ingress.key --cert ingress.crt
# secret/ingress-tls created

kubectl describe secret ingress-tls
# Name:         ingress-tls
# Namespace:    default
# Labels:       <none>
# Annotations:  <none>

# Type:  kubernetes.io/tls

# Data
# ====
# tls.crt:  1184 bytes
# tls.key:  1708 bytes
```

### Create ingress

```sh
# create ingress
kubectl create ingress ingress-tls --class=nginx --rule=example.internal/*=ingress-tls:80,tls=ingress-tls
# ingress.networking.k8s.io/ingress-tls created

kubectl describe ingress ingress-tls
# Name:             ingress-tls
# Labels:           <none>
# Namespace:        default
# Address:
# Ingress Class:    nginx
# Default backend:  <default>
# TLS:
#   ingress-tls terminates example.internal
# Rules:
#   Host              Path  Backends
#   ----              ----  --------
#   example.internal
#                     /   ingress-tls:80 (10.244.196.138:80)
# Annotations:        <none>
# Events:
#   Type    Reason  Age   From                      Message
#   ----    ------  ----  ----                      -------
#   Normal  Sync    15s   nginx-ingress-controller  Scheduled for sync

# confirm: connect; CN=example.internal; O=security
curl -kv --resolve example.internal:31178:192.168.10.181 https://example.internal:31178/
# * Added example.internal:31178:192.168.10.181 to DNS cache
# * Hostname example.internal was found in DNS cache
# *   Trying 192.168.10.181:31178...
# * Connected to example.internal (192.168.10.181) port 31178
# * ALPN: curl offers h2,http/1.1
# * TLSv1.3 (OUT), TLS handshake, Client hello (1):
# * TLSv1.3 (IN), TLS handshake, Server hello (2):
# * TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
# * TLSv1.3 (IN), TLS handshake, Certificate (11):
# * TLSv1.3 (IN), TLS handshake, CERT verify (15):
# * TLSv1.3 (IN), TLS handshake, Finished (20):
# * TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
# * TLSv1.3 (OUT), TLS handshake, Finished (20):
# * SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / RSASSA-PSS
# * ALPN: server accepted h2
# * Server certificate:
# *  subject: CN=example.internal; O=security
# *  start date: Sep  6 20:52:10 2026 GMT
# *  expire date: Sep  6 20:52:10 2027 GMT
# *  issuer: CN=example.internal; O=security
# *  SSL certificate verify result: self-signed certificate (18), continuing anyway.
# *   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
# * using HTTP/2
# * [HTTP/2] [1] OPENED stream for https://example.internal:31178/
# * [HTTP/2] [1] [:method: GET]
# * [HTTP/2] [1] [:scheme: https]
# * [HTTP/2] [1] [:authority: example.internal:31178]
# * [HTTP/2] [1] [:path: /]
# * [HTTP/2] [1] [user-agent: curl/8.5.0]
# * [HTTP/2] [1] [accept: */*]
# > GET / HTTP/2
# > Host: example.internal:31178
# > User-Agent: curl/8.5.0
# > Accept: */*
# >
# * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
# * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
# * old SSL session ID is stale, removing
# < HTTP/2 200
# < date: Sun, 06 Sep 2026 21:43:47 GMT
# < content-type: text/html
# < content-length: 896
# < last-modified: Wed, 02 Sep 2026 11:17:13 GMT
# < etag: "6a9805b9-380"
# < accept-ranges: bytes
# < strict-transport-security: max-age=31536000; includeSubDomains
# <
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# <style>
# html { color-scheme: light dark; }
# body { width: 35em; margin: 0 auto;
# font-family: Tahoma, Verdana, Arial, sans-serif; }
# </style>
# </head>
# <body>
# <h1>Welcome to nginx!</h1>
# <p>If you see this page, nginx is successfully installed and working.
# Further configuration is required for the web server, reverse proxy,
# API gateway, load balancer, content cache, or other features.</p>

# <p>For online documentation and support please refer to
# <a href="https://nginx.org/">nginx.org</a>.<br/>
# To engage with the community please visit
# <a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
# For enterprise grade support, professional services, additional
# security features and capabilities please refer to
# <a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

# <p><em>Thank you for using nginx.</em></p>
# </body>
# </html>
# * Connection #0 to host example.internal left intact
```

### redirect

```sh
# http port: 30344
kubectl get service -n ingress-nginx
# NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
# ingress-nginx-controller             LoadBalancer   10.103.247.144   <pending>     80:30344/TCP,443:31178/TCP   79m

# confirm
curl -i --resolve example.internal:30344:192.168.10.181 http://example.internal:30344/
# HTTP/1.1 308 Permanent Redirect
# Date: Sun, 06 Sep 2026 22:05:26 GMT
# Content-Type: text/html
# Content-Length: 164
# Connection: keep-alive
# Location: https://example.internal

# <html>
# <head><title>308 Permanent Redirect</title></head>
# <body>
# <center><h1>308 Permanent Redirect</h1></center>
# <hr><center>nginx</center>
# </body>
# </html>

# disable redirect
kubectl edit ingress ingress-tls
# metadata:
#   annotations:
#     nginx.ingress.kubernetes.io/ssl-redirect: "false"

# test http: no redict; return website 200
curl -i --resolve example.internal:30344:192.168.10.181 http://example.internal:30344/
# HTTP/1.1 200 OK
# Date: Sun, 06 Sep 2026 22:08:57 GMT
# Content-Type: text/html
# Content-Length: 896
# Connection: keep-alive
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# <style>
# html { color-scheme: light dark; }
# body { width: 35em; margin: 0 auto;
# font-family: Tahoma, Verdana, Arial, sans-serif; }
# </style>
# </head>
# <body>
# <h1>Welcome to nginx!</h1>
# <p>If you see this page, nginx is successfully installed and working.
# Further configuration is required for the web server, reverse proxy,
# API gateway, load balancer, content cache, or other features.</p>

# <p>For online documentation and support please refer to
# <a href="https://nginx.org/">nginx.org</a>.<br/>
# To engage with the community please visit
# <a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
# For enterprise grade support, professional services, additional
# security features and capabilities please refer to
# <a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

# <p><em>Thank you for using nginx.</em></p>
# </body>
# </html>
```

- clean up

```sh
kubectl delete pod ingress-tls
kubectl delete service ingress-tls
kubectl delete ingress ingress-tls
kubectl delete secret ingress-tls
```
