# CKS - Architecture: scheduler

[Back](../../index.md)

- [CKS - Architecture: scheduler](#cks---architecture-scheduler)
  - [scheduler](#scheduler)
  - [Lab: Stop scheduler](#lab-stop-scheduler)

---

## scheduler

- select node to run pod

---

## Lab: Stop scheduler

- Before stop

```sh
# confirm schduler active
systemctl status kube-scheduler
# ● kube-scheduler.service - Kubernetes Scheduler
#      Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:02:21 EDT; 16min ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 51164 (kube-scheduler)
#       Tasks: 8 (limit: 3179)
#      Memory: 57.2M (peak: 57.7M)
#         CPU: 4.322s
#      CGroup: /system.slice/kube-scheduler.service

# run a pod
kubectl run scheduler-before --image=nginx
# pod/scheduler-before created

# confirm
kubectl get po
# NAME               READY   STATUS    RESTARTS   AGE
# scheduler-before   1/1     Running   0          17s
```

- Stop

```sh
# stop
sudo systemctl stop kube-scheduler
# confirm
systemctl status kube-scheduler
# ○ kube-scheduler.service - Kubernetes Scheduler
#      Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 10:20:28 EDT; 6s ago
#    Duration: 18min 6.395s
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#     Process: 51164 ExecStart=/usr/local/bin/kube-scheduler --config=/etc/kubernetes/config/kube-sched>
#    Main PID: 51164 (code=exited, status=0/SUCCESS)
#         CPU: 4.804s

# run a pod
kubectl run scheduler-after --image=nginx
# pod/scheduler-after created

# confirm
kubectl get po
# NAME               READY   STATUS    RESTARTS   AGE
# scheduler-after    0/1     Pending   0          18s
# scheduler-before   1/1     Running   0          2m10s
```

- restore

```sh
# restore
sudo systemctl start kube-scheduler
# confirm
systemctl status kube-scheduler
# ● kube-scheduler.service - Kubernetes Scheduler
#      Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:22:56 EDT; 12s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 60825 (kube-scheduler)
#       Tasks: 8 (limit: 3179)
#      Memory: 14.4M (peak: 14.9M)
#         CPU: 1.192s
#      CGroup: /system.slice/kube-scheduler.service

# comfirm
kubectl get po
# NAME               READY   STATUS    RESTARTS   AGE
# scheduler-after    1/1     Running   0          2m19s
# scheduler-before   1/1     Running   0          4m11s
```
