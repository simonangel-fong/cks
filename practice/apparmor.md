# Practices - AppArmor

[Back](../README.md)

- [Practices - AppArmor](#practices---apparmor)
  - [Kernel Hardening using AppArmor](#kernel-hardening-using-apparmor)
    - [debug](#debug)

---

## Kernel Hardening using AppArmor

- ref: https://kubernetes.io/docs/tutorials/security/apparmor/
- task:
  - profile path: `/etc/apparmor.d/k8s-apparmor-example-deny-write`

- setup env:

```sh
# worker node: node01
sudo tee /etc/apparmor.d/k8s-apparmor-example-deny-write s<<EOF
#include <tunables/global>

profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
EOF
```

- solution

```sh
# module is enabled
cat /sys/module/apparmor/parameters/enabled
# Y

# confirm aa status by listing profile
sudo aa-status

# ##############################
# create a sample profile
# ##############################
# in worker node
ssh node01
# create profile
sudo apparmor_parser -rq /etc/apparmor.d/k8s-apparmor-example-deny-write

# confirm
sudo aa-status | grep apparmor-example-deny-write
#    k8s-apparmor-example-deny-write
```

```yaml
# vi apparmor-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-example-deny-write
  containers:
    - name: hello
      image: busybox:1.28
      command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 1h"]
```

```sh
kubectl create -f apparmor-pod.yaml
# pod/hello-apparmor created

k get po hello-apparmor -o wide
# NAME             READY   STATUS    RESTARTS   AGE   IP               NODE     NOMINATED NODE   READINESS GATES
# hello-apparmor   1/1     Running   0          85s   10.244.196.142   node01   <none>           <none>

# confirm
kubectl exec hello-apparmor -- cat /proc/1/attr/current
# k8s-apparmor-example-deny-write (enforce)

# test
kubectl exec hello-apparmor -- touch /tmp/test
# touch: /tmp/test: Permission denied
# command terminated with exit code 1
```

### debug

```sh
# create a pod referencing non-existing profile
kubectl create -f /dev/stdin <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor-2
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-no-profile
  containers:
  - name: hello
    image: busybox:1.28
    command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
EOF
# pod/hello-apparmor-2 created

# fails
k get pod hello-apparmor-2
# NAME               READY   STATUS                 RESTARTS   AGE
# hello-apparmor-2   0/1     CreateContainerError   0          22s

kubectl describe pod hello-apparmor-2
# Events:
#   Type     Reason     Age               From               Message
#   ----     ------     ----              ----               -------
#   Normal   Scheduled  47s               default-scheduler  Successfully assigned default/hello-apparmor-2 to node01
#   Normal   Pulled     9s (x6 over 46s)  kubelet            spec.containers{hello}: Container image "busybox:1.28" already present on machine and can be accessed by the pod
#   Warning  Failed     9s (x6 over 46s)  kubelet            spec.containers{hello}: Error: failed to get container spec opts: failed to generate apparmor spec opts: apparmor profile not found k8s-apparmor-no-profile
```
