# CKS - Architecture: kubelet

[Back](../../index.md)

- [CKS - Architecture: kubelet](#cks---architecture-kubelet)
  - [kubelet](#kubelet)
  - [Lab: stop kubelet](#lab-stop-kubelet)

---

## kubelet

- node agent
- interact with CRI

---

## Lab: stop kubelet

```sh
# stop kubelet
sudo systemctl stop kubelet
systemctl status kubelet
# ○ kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 11:10:02 EDT; 4s ago
#    Duration: 1h 11min 44.847s
#     Process: 1389 ExecStart=/usr/local/bin/kubelet --config=/var/lib/kubelet/kubelet-config.yaml --ku>
#    Main PID: 1389 (code=exited, status=0/SUCCESS)
#         CPU: 1min 38.818s

# controlplane: create deploy
kubectl create deploy web --image=nginx --replicas=2
# deployment.apps/web created

kubectl get deploy
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    0/2     2            0           5s

# deployment get scalled up
kubectl describe deploy web
# Events:
#   Type    Reason             Age   From                   Message
#   ----    ------             ----  ----                   -------
#   Normal  ScalingReplicaSet  31s   deployment-controller  Scaled up replica set web-68d995574f from 0 to 2

# po get pending
kubectl get po
# NAME                   READY   STATUS    RESTARTS   AGE
# web-68d995574f-hw757   0/1     Pending   0          83s
# web-68d995574f-wfggv   0/1     Pending   0          83s

# po get scheduled
kubectl describe po web-68d995574f-hw757
# Events:
#   Type    Reason     Age   From               Message
#   ----    ------     ----  ----               -------
#   Normal  Scheduled  2m    default-scheduler  Successfully assigned default/web-68d995574f-hw757 to controlplane
```

- restore

```sh
sudo systemctl start kubelet
systemctl status kubelet
# ● kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 11:17:36 EDT; 5s ago
#    Main PID: 74958 (kubelet)
#       Tasks: 12 (limit: 3179)
#      Memory: 72.1M (peak: 72.4M)
#         CPU: 1.167s
#      CGroup: /system.slice/kubelet.service

kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    2/2     2            2           3m56s
```
