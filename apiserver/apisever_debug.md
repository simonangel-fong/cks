# CKS: `kube-apiserver` - debug

[Back](../README.md)

- [CKS: `kube-apiserver` - debug](#cks-kube-apiserver---debug)
  - [Lab: Stop kube-apiserver](#lab-stop-kube-apiserver)

---

## Lab: Stop kube-apiserver

- Stop api server
  - query api fails

```sh
# take minutes
sudo systemctl stop kube-apiserver

sudo systemctl status kube-apiserver
# Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 09:38:28 EDT; 3min 25s ago
#    Duration: 22min 10.069s
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#     Process: 1150 ExecStart=/usr/local/bin/kube-apiserver --advertise-address=192.168.10.180 --secure>
#    Main PID: 1150 (code=exited, status=0/SUCCESS)
#         CPU: 1min 41.143s

# api access fails
kubectl get node
# The connection to the server 127.0.0.1:6443 was refused - did you specify the right host or port?
```

- Others are running

```sh
# other components
systemctl status kube-scheduler
# ● kube-scheduler.service - Kubernetes Scheduler
#      Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 09:38:28 EDT; 5min ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 32365 (kube-scheduler)
#       Tasks: 8 (limit: 3179)
#      Memory: 12.4M (peak: 13.4M)
#         CPU: 1.555s
#      CGroup: /system.slice/kube-scheduler.service

systemctl status etcd
# ● etcd.service - etcd
#      Loaded: loaded (/etc/systemd/system/etcd.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 09:15:17 EDT; 29min ago
#        Docs: https://github.com/etcd-io/etcd
#    Main PID: 950 (etcd)
#       Tasks: 10 (limit: 3179)
#      Memory: 55.9M (peak: 110.8M)
#         CPU: 41.881s
#      CGroup: /system.slice/etcd.service

# containers are running
sudo crictl ps
# CONTAINER           IMAGE               CREATED              STATE               NAME                        ATTEMPT             POD ID              POD                                        NAMESPACE
# 590fa6879a180       81a30a7a24037       13 seconds ago       Running             calico-kube-controllers     3                   6651bdbaab8f9       calico-kube-controllers-5b5647977c-vsg9g   calico-system
# 95a6b9e36fe65       c5f89ea6b7611       About a minute ago   Running             calico-node                 7                   3f4e7f9367969       calico-node-8z5gs                          calico-system
# 24ac4cac81ebc       c153c8a1cbce1       26 minutes ago       Running             csi-node-driver-registrar   2                   3ec7c44a7e43e       csi-node-driver-4wqr9                      calico-system
# 17004b0468fba       27f5caaa5abb4       26 minutes ago       Running             calico-csi                  2                   3ec7c44a7e43e       csi-node-driver-4wqr9                      calico-system
# 60ee82a06bd41       d7eef55efdbf0       26 minutes ago       Running             whisker-backend             2                   7143af3736c63       whisker-6bd9f75f44-zprzq                   calico-system
# e68257372b970       4d4438fe7d587       26 minutes ago       Running             calico-apiserver            2                   339e41dfa727f       calico-apiserver-64d74c9474-cpphv          calico-system
# be42fd8defca1       aa5e3ebc0dfed       26 minutes ago       Running             coredns                     2                   c10281d34d778       coredns-5c44b89985-gnzph                   kube-system
# 52f1821f2f8e3       4d4438fe7d587       26 minutes ago       Running             calico-apiserver            2                   8ca812bf7b08d       calico-apiserver-64d74c9474-nxp5s          calico-system
# 393f34d9da774       db36509507e0d       26 minutes ago       Running             whisker                     2                   7143af3736c63       whisker-6bd9f75f44-zprzq                   calico-system
# 2d1beb714c94b       0d9d29e9b0f25       27 minutes ago       Running             goldmane                    2                   e4a03d9b576f5       goldmane-5d7c56cd95-nqrpb                  calico-system
# 676033b9acab5       da0f412e3f4c3       27 minutes ago       Running             calico-typha                2                   e89fdfc71d7ca       calico-typha-77b497cd9c-rq2x4              calico-system

```

- Spin back

```sh
sudo systemctl start kube-apiserver
sudo systemctl status kube-apiserver
# ● kube-apiserver.service - Kubernetes API Server
#      Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 09:46:54 EDT; 6s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 40172 (kube-apiserver)
#       Tasks: 10 (limit: 3179)
#      Memory: 246.4M (peak: 246.8M)
#         CPU: 2.026s
#      CGroup: /system.slice/kube-apiserver.service

kubectl get po -A
# NAMESPACE         NAME                                       READY   STATUS    RESTARTS        AGE
# calico-system     calico-kube-controllers-5b5647977c-vsg9g   1/1     Running   6 (61s ago)     10h
# calico-system     calico-node-mlzdd                          1/1     Running   0               9h
# calico-system     calico-typha-77b497cd9c-rq2x4              1/1     Running   2 (32m ago)     10h
# calico-system     csi-node-driver-4wqr9                      2/2     Running   4 (32m ago)     10h
# calico-system     csi-node-driver-wnx8x                      2/2     Running   0               9h
# calico-system     goldmane-5d7c56cd95-nqrpb                  1/1     Running   2 (32m ago)     10h
# calico-system     whisker-6bd9f75f44-zprzq                   2/2     Running   4 (32m ago)     10h
# kube-system       coredns-5c44b89985-gnzph                   1/1     Running   2 (32m ago)     10h
# tigera-operator   tigera-operator-676bbdd645-lw8fw           1/1     Running   3 (9m47s ago)   10h
```
