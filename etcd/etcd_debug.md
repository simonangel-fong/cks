# CKS: `etcd` - debug

[Back](../README.md)

- [CKS: `etcd` - debug](#cks-etcd---debug)
  - [Lab: Stop etcd](#lab-stop-etcd)

---

## Lab: Stop etcd

- before stop

```sh
# current running
systemctl status etcd --no-page
# ● etcd.service - etcd
#      Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 09:15:17 EDT; 34min ago
#        Docs: https://github.com/etcd-io/etcd
#    Main PID: 950 (etcd)
#       Tasks: 10 (limit: 3179)
#      Memory: 89.2M (peak: 110.8M)
#         CPU: 47.825s
#      CGroup: /system.slice/etcd.service

kubectl run etcd-before --image=nginx
# pod/etcd-before created
```

- stop
  - api server also stops

```sh
kubectl get po
# NAME          READY   STATUS    RESTARTS   AGE
# etcd-before   1/1     Running   0          5m55s

# stop
sudo systemctl stop etcd
sudo systemctl status etcd
# ○ etcd.service - etcd
#      Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 09:51:29 EDT; 26s ago
#    Duration: 36min 11.682s
#        Docs: https://github.com/etcd-io/etcd
#     Process: 950 ExecStart=/usr/local/bin/etcd --name controlplane --advertise-client-urls https://19>
#    Main PID: 950 (code=killed, signal=TERM)
#         CPU: 49.971s

# api server also stop
sudo systemctl status kube-apiserver
# ○ kube-apiserver.service - Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 10:02:21 EDT; 1min 1s ago
#    Duration: 7min 42.164s
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#     Process: 46719 ExecStart=/usr/local/bin/kube-apiserver --advertise-address=192.168.10.180 --secur>
#    Main PID: 46719 (code=exited, status=0/SUCCESS)
#         CPU: 33.592s

# get pod
kubectl get pods
# The connection to the server 127.0.0.1:6443 was refused - did you specify the right host or port?
```

- restart etcd

```sh
# start
sudo systemctl start etcd
# confirm
sudo systemctl status etcd
# ● etcd.service - etcd
#      Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:06:46 EDT; 10s ago
#        Docs: https://github.com/etcd-io/etcd
#    Main PID: 55114 (etcd)
#       Tasks: 8 (limit: 3179)
#      Memory: 55.5M (peak: 58.5M)
#         CPU: 300ms
#      CGroup: /system.slice/etcd.service

# start api server
sudo systemctl start kube-apiserver
sudo systemctl status kube-apiserver
# ● kube-apiserver.service - Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:07:53 EDT; 1s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 56265 (kube-apiserver)
#       Tasks: 8 (limit: 3179)
#      Memory: 182.6M (peak: 182.6M)
#         CPU: 1.564s
#      CGroup: /system.slice/kube-apiserver.service

# get pod
kubectl get pods
# NAME          READY   STATUS    RESTARTS   AGE
# etcd-before   1/1     Running   0          13m

```
