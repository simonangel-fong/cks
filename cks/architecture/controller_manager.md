# CKS - Architecture: Controller manager

[Back](../../index.md)

- [CKS - Architecture: Controller manager](#cks---architecture-controller-manager)
  - [Controller manager](#controller-manager)
  - [Lab: stop controller manager](#lab-stop-controller-manager)

---

## Controller manager

- reconcile diff between desired and actual

---

## Lab: stop controller manager

- service account controller
  - when a new ns is created a default sa will be created.
  - if sa controller is down, sa will not create.

```sh
systemctl status kube-controller-manager
# ● kube-controller-manager.service - Kubernetes Controller Manager
#      Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:02:21 EDT; 37min ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 51162 (kube-controller)
#       Tasks: 6 (limit: 3179)
#      Memory: 112.7M (peak: 127.0M)
#         CPU: 45.315s
#      CGroup: /system.slice/kube-controller-manager.service

kubectl create ns before
# namespace/before created

kubectl get ns before
# NAME     STATUS   AGE
# before   Active   31s

kubectl get sa -n before
# NAME      AGE
# default   47s

# stop
sudo systemctl stop kube-controller-manager
# confirm
sudo systemctl status kube-controller-manager
# ○ kube-controller-manager.service - Kubernetes Controller Manager
#      Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 10:42:37 EDT; 9s ago
#    Duration: 40min 15.602s
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#     Process: 51162 ExecStart=/usr/local/bin/kube-controller-manager --allocate-node-cidrs=true --auth>
#    Main PID: 51162 (code=killed, signal=TERM)
#         CPU: 47.916s

kubectl create ns after
# namespace/after created

kubectl get ns after
# NAME    STATUS   AGE
# after   Active   15s

# no sa
kubectl get sa -n after
# No resources found in after namespace.

# restore
sudo systemctl start kube-controller-manager

# sa created
kubectl get sa -n after
# NAME      AGE
# default   4s
```

- deployment vs pod
  - deployment cannot scale
  - pod can run

```sh
# stop
sudo systemctl stop kube-controller-manager
# confirm
sudo systemctl status kube-controller-manager
# ○ kube-controller-manager.service - Kubernetes Controller Manager
#      Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; preset: enabled)
#      Active: inactive (dead) since Fri 2026-09-04 10:46:54 EDT; 3min 2s ago
#    Duration: 2min 22.141s
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#     Process: 65728 ExecStart=/usr/local/bin/kube-controller-manager --allocate-node-cidrs=true --auth>
#    Main PID: 65728 (code=killed, signal=TERM)
#         CPU: 4.944s

kubectl create deploy web --image=nginx --replicas=2
# deployment.apps/web created

kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    0/2     0            0           21s

kubectl run web --image=nginx
# pod/web created

kubectl get po web
# NAME   READY   STATUS    RESTARTS   AGE
# web    1/1     Running   0          18s

# restore
sudo systemctl start kube-controller-manager
systemctl status kube-controller-manager
# ● kube-controller-manager.service - Kubernetes Controller Manager
#      Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 10:54:53 EDT; 22s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 68206 (kube-controller)
#       Tasks: 5 (limit: 3179)
#      Memory: 49.4M (peak: 49.8M)
#         CPU: 674ms
#      CGroup: /system.slice/kube-controller-manager.service

kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    2/2     2            2           5m2s
```

- Stop again to observe deployment scale down

```sh
# stop
sudo systemctl stop kube-controller-manager

# scale down
kubectl scale deploy web --replicas=0
# deployment.apps/web scaled

# confirm: actual=2; desired =0
kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    2/0     2            2           7m19s

# retore
sudo systemctl start kube-controller-manager
kubectl get deploy web
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web    0/0     0            0           8m30s
```
