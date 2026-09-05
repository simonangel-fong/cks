# CKS - Architecture: container runtime

[Back](../../index.md)

- [CKS - Architecture: container runtime](#cks---architecture-container-runtime)
  - [container runtime](#container-runtime)
  - [Lab: stop containerd](#lab-stop-containerd)

---

## container runtime

- manages the lifecycle of containers.

---

## Lab: stop containerd

```sh
# stop runime
sudo systemctl stop containerd
# confirm
sudo systemctl status containerd
# ○ containerd.service - containerd container runtime
#      Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 12:47:23 EDT; 4s ago
#    Duration: 3h 32min 6.401s
#        Docs: https://containerd.io
#     Process: 927 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
#     Process: 936 ExecStart=/usr/bin/containerd (code=exited, status=0/SUCCESS)
#    Main PID: 936 (code=exited, status=0/SUCCESS)
#       Tasks: 113
#      Memory: 294.7M (peak: 593.0M)
#         CPU: 5min 12.845s
#      CGroup: /system.slice/containerd.service

# kubelet goes down as well
sudo systemctl status kubelet
# ○ kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 12:56:39 EDT; 11s ago
#    Duration: 3.888s
#     Process: 100757 ExecStart=/usr/local/bin/kubelet --config=/var/lib/kubelet/kubelet-config.yaml -->
#    Main PID: 100757 (code=exited, status=0/SUCCESS)
#         CPU: 1.637s

kubectl create deploy web --image=nginx --replicas=2
# deployment.apps/web created

kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    0/2     2            0           19s

kubectl get po
# NAME                   READY   STATUS    RESTARTS   AGE
# web-68d995574f-ltjgr   0/1     Pending   0          41s
# web-68d995574f-nh6p6   0/1     Pending   0          41s

kubectl describe po web-68d995574f-ltjgr
# Events:
#   Type     Reason            Age    From               Message
#   ----     ------            ----   ----               -------
#   Warning  FailedScheduling  3m45s  default-scheduler  0/2 nodes are available: 2 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.

# cri connect fails
sudo crictl ps
# FATA[0000] validate service connection: validate CRI v1 runtime API for endpoint "unix:///run/containerd/containerd.sock": rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial unix /run/containerd/containerd.sock: connect: no such file or directory"
```

- restore

```sh
# restore runime
sudo systemctl start containerd
sudo systemctl start kubelet
# confirm
sudo systemctl status containerd
# ● containerd.service - containerd container runtime
#      Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 12:53:31 EDT; 6s ago
#        Docs: https://containerd.io
#     Process: 100279 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
#    Main PID: 100280 (containerd)
#       Tasks: 123
#      Memory: 325.8M (peak: 593.0M)
#         CPU: 541ms
#      CGroup: /system.slice/containerd.service

sudo systemctl status kubelet
# ● kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 12:59:01 EDT; 5s ago
#    Main PID: 101514 (kubelet)
#       Tasks: 12 (limit: 3179)
#      Memory: 45.0M (peak: 45.4M)
#         CPU: 1.073s
#      CGroup: /system.slice/kubelet.service

kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    2/2     2            2           2m56s

sudo crictl ps
# CONTAINER           IMAGE               CREATED              STATE               NAME                        ATTEMPT             POD ID              POD                                        NAMESPACE
# bd0ce7ef818d6       5f52b9aca7a79       About a minute ago   Running             nginx                       0                   4a754af901f70       web-68d995574f-xsfj4                       default
# 991a0c48b1421       5f52b9aca7a79       About a minute ago   Running             nginx                       0                   41afe0084c9e6       web-68d995574f-q52sv                       default
# 1e3e374d441f4       d7eef55efdbf0       About a minute ago   Running             whisker-backend             0                   3a24887c451fb       whisker-6bd9f75f44-76t7d                   calico-system
# 7d69f50cbc6d4       db36509507e0d       About a minute ago   Running             whisker                     0                   3a24887c451fb       whisker-6bd9f75f44-76t7d                   calico-system
# 83b175b5cbe9e       4d4438fe7d587       About a minute ago   Running             calico-apiserver            0                   ddceed1526dee       calico-apiserver-64d74c9474-vk6xv          calico-system
# c22eb3fe190a1       4d4438fe7d587       About a minute ago   Running             calico-apiserver            0                   316bbfa300f4c       calico-apiserver-64d74c9474-gtsgf          calico-system
# 835bb895a69ca       81a30a7a24037       About a minute ago   Running             calico-kube-controllers     0                   4e45bac9e37e1       calico-kube-controllers-5b5647977c-wp525   calico-system
# 14aeb256b8a50       0d9d29e9b0f25       About a minute ago   Running             goldmane                    0                   35ea279d83c7c       goldmane-5d7c56cd95-khkkv                  calico-system
# 57c55aa4fa72c       aa5e3ebc0dfed       About a minute ago   Running             coredns                     0                   07eddb2300c01       coredns-5c44b89985-pfgcn                   kube-system
# 5d065cd822a58       1fa70046222eb       3 hours ago          Running             tigera-operator             6                   50e358c37b5cb       tigera-operator-676bbdd645-lw8fw           tigera-operator
# 49068fa6268f5       c5f89ea6b7611       3 hours ago          Running             calico-node                 11                  3f4e7f9367969       calico-node-8z5gs                          calico-system
# 24ac4cac81ebc       c153c8a1cbce1       4 hours ago          Running             csi-node-driver-registrar   2                   3ec7c44a7e43e       csi-node-driver-4wqr9                      calico-system
# 17004b0468fba       27f5caaa5abb4       4 hours ago          Running             calico-csi                  2                   3ec7c44a7e43e       csi-node-driver-4wqr9                      calico-system
# 676033b9acab5       da0f412e3f4c3       4 hours ago          Running             calico-typha                2                   e89fdfc71d7ca       calico-typha-77b497cd9c-rq2x4              calico-system
```
