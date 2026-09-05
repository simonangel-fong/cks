# CKS - Architecture: kube-proxy

[Back](../../index.md)

- [CKS - Architecture: kube-proxy](#cks---architecture-kube-proxy)
  - [kube-proxy](#kube-proxy)
  - [Lab: stop kube-proxy](#lab-stop-kube-proxy)

---

## kube-proxy

- route and load-balance traffic

---

## Lab: stop kube-proxy

- before

```sh
systemctl status kube-proxy
# ● kube-proxy.service - Kubernetes Kube Proxy
#      Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 09:15:17 EDT; 2h 15min ago
#    Main PID: 1156 (kube-proxy)
#       Tasks: 8 (limit: 3179)
#      Memory: 54.9M (peak: 58.1M)
#         CPU: 8.269s
#      CGroup: /system.slice/kube-proxy.service

# create a deployment
kubectl create deploy web --image=nginx --replicas=2
# deployment.apps/web created

# get ip
kubectl get po -o wide -l app=web
# NAME                   READY   STATUS    RESTARTS   AGE   IP             NODE           NOMINATED NODE   READINESS GATES
# web-68d995574f-cnt6d   1/1     Running   0          36s   10.244.49.97   controlplane   <none>           <none>
# web-68d995574f-cr5x8   1/1     Running   0          36s   10.244.49.98   controlplane   <none>           <none>

# create svc
kubectl expose deploy web --port=80 --target-port=80
# service/web exposed

kubectl get svc
# web          ClusterIP   10.100.23.238   <none>        80/TCP    24s

kubectl run curl-po --image=alpine/curl -- sleep 3600
# pod/curl-po created

kubectl get pod curl-po
# NAME      READY   STATUS    RESTARTS   AGE
# curl-po   1/1     Running   0          5s

# test connection with svc
kubectl exec curl-po -- curl -I 10.100.23.238
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Fri, 04 Sep 2026 15:47:04 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

#   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
#                                  Dload  Upload  Total   Spent   Left   Speed
#   0    896   0      0   0      0      0      0                              0

# test with pod
kubectl exec curl-po -- curl -I 10.244.49.97
#   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
#                                  Dload  Upload  Total   Spent   Left   Speed
#   0    896   0      0   0      0      0      0                              0
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Fri, 04 Sep 2026 15:47:34 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

```

- stop
  - svc test fails, as underlying iptables fails due to proxy

```sh
sudo systemctl stop kube-proxy
sudo systemctl status kube-proxy
# ○ kube-proxy.service - Kubernetes Kube Proxy
#      Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 11:41:07 EDT; 6s ago
#    Duration: 2h 25min 49.194s
#     Process: 1156 ExecStart=/usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.>
#    Main PID: 1156 (code=killed, signal=TERM)
#         CPU: 8.553s

# create new deploy and expose
kubectl create deploy web-new --image=nginx --replicas=2
# deployment.apps/web-new created

kubectl expose deploy web-new --port=80 --target-port=80
# service/web-new exposed

# confirm
kubectl get pod -l app=web-new -o wide
# NAME                       READY   STATUS    RESTARTS   AGE    IP              NODE           NOMINATED NODE   READINESS GATES
# web-new-74f78bc598-bnwjj   1/1     Running   0          102s   10.244.49.100   controlplane   <none>           <none>
# web-new-74f78bc598-zs7vp   1/1     Running   0          102s   10.244.49.99    controlplane   <none>           <none>

kubectl get svc web-new
# NAME      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
# web-new   ClusterIP   10.101.185.169   <none>        80/TCP    90s

# test with pod
kubectl exec curl-po -- curl -I 10.244.49.100
#   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
#                                  Dload  Upload  Total   Spent   Left   Speed
#   0    896   0      0   0      0      0      0                              0
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Fri, 04 Sep 2026 15:48:15 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

# test connection with svc
kubectl exec curl-po -- curl -I 10.101.185.169
# curl: (7) Failed to connect to 10.101.185.169:80 after 2309 ms: Could not connect to server
# command terminated with exit code 7
```

- restore

```sh
sudo systemctl status kube-proxy
# ● kube-proxy.service - Kubernetes Kube Proxy
#      Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 11:48:48 EDT; 16s ago
#    Main PID: 84777 (kube-proxy)
#       Tasks: 5 (limit: 3179)
#      Memory: 38.2M (peak: 42.2M)
#         CPU: 920ms
#      CGroup: /system.slice/kube-proxy.service

# test svc
kubectl exec curl-po -- curl -I 10.101.185.169
# HTTP/1.1 200 OK
# Server: nginx/1.31.5
# Date: Fri, 04 Sep 2026 15:49:47 GMT
# Content-Type: text/html
# Content-Length: 896
# Last-Modified: Wed, 02 Sep 2026 11:17:13 GMT
# Connection: keep-alive
# ETag: "6a9805b9-380"
# Accept-Ranges: bytes

#   % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
#                                  Dload  Upload  Total   Spent   Left   Speed
#   0    896   0      0   0      0      0      0                              0
```
