# Practices - Pod Security Context AppArmor

[Back](../../README.md)

- [Practices - Pod Security Context AppArmor](#practices---pod-security-context-apparmor)
  - [Recap](#recap)
    - [apparmor](#apparmor)
    - [seccomp](#seccomp)
    - [apply seccomp to pod](#apply-seccomp-to-pod)
    - [AppArmor](#apparmor-1)
  - [Pod Security Context: AppArmor](#pod-security-context-apparmor)
  - [AppArmor (killer A)](#apparmor-killer-a)

---

## Recap

- syscall

| cmd                   | desc                                  |
| --------------------- | ------------------------------------- |
| `strace <command>`    | show syscall of a command             |
| `strace -c <command>` | Get a Performance Summary (Profiling) |
| `strace -p <pid>`     | Attach to a Running Process           |

---

### apparmor

- default profile path:
 - `/etc/apparmor.`

---

### seccomp

- `Seccomp` (`Secure Computing Mode`)
  - a security feature in the Linux kernel that **restricts** the `system calls (syscalls)` a process can make.

- seccomp mode:
  - disabled: `0`
  - strict: `1`
    - only allow system calls: `read`, `write`, `_exit`, and `sigreturn`
  - filter: `2`
    - lets developers whitelist or blacklist specific system calls
    - use case: contianer

```sh
# LInux: confirm seccomp enable
grep -i seccomp /boot/config-$(uname -r)
# CONFIG_HAVE_ARCH_SECCOMP=y
# CONFIG_HAVE_ARCH_SECCOMP_FILTER=y
# CONFIG_SECCOMP=y
# CONFIG_SECCOMP_FILTER=y
# # CONFIG_SECCOMP_CACHE_DEBUG is not set
```

- by default, k8s use filtering seccomp mode

```sh
kubectl run amicontained --image=jess/amicontained:latest --rm -it -- amicontained
# AppArmor Profile: kernel
# Capabilities:
#         BOUNDING -> chown dac_override fowner fsetid kill setgid setuid setpcap net_bind_service net_raw sys_chroot mknod audit_write setfcap
# Seccomp: filtering
# Blocked Syscalls (19):
#         MSGRCV SYSLOG SETPGID SETSID VHANGUP PIVOT_ROOT ACCT SETTIMEOFDAY SWAPON SWAPOFF REBOOT SETHOSTNAME SETDOMAINNAME INIT_MODULE DELETE_MODULE FANOTIFY_INIT FINIT_MODULE KEXEC_FILE_LOAD USERFAULTFD
# pod "amicontained" deleted from default namespace

```

---

### apply seccomp to pod

- default seccomp profile paths:
  - `/var/lib/kubelet/seccomp`

- `kubelet` flag:
  - `--seccomp-default`: set default seccomp profile for all workloads

- field
  - `type`: `RuntimeDefault`, `Unconfined`, and `Localhost`.
  - `localhostProfile` must only be set if `type: Localhost`.

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault

securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: my-profiles/profile-allow.json
    # path of kubelet --root-dir flag; e.g. <kubelet-root-dir>/seccomp/my-profiles/profile-allow.json
```

```yaml
# pod-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-seccomp
  labels:
    app: pod-seccomp
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: RuntimeDefault # runtime default seccomp profile
  containers:
    - name: test-container
      image: jess/amicontained:latest
      args:
        - "amicontained"
      securityContext:
        allowPrivilegeEscalation: false
```

---

### AppArmor

- rules:

```conf
#include <tunables/global>

profile apparmor-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
```

> profile name: `apparmor-deny-write`
> `file`: allow file system
> `deny /** w,`: Deny all file writes.
> can specify a path:
> `deny /proc/* w,`

---

## Pod Security Context: AppArmor

- ref: https://kubernetes.io/docs/tutorials/security/apparmor/
- task:
  - exiting apparmor profile path: `/etc/apparmor.d/k8s-apparmor-deny-write`
  - create a deploy named `apparmor` and secure using the apparmor profile
    - image: `busybox:1.28`

- setup env:

```sh
# worker node: node01
sudo tee /etc/apparmor.d/k8s-apparmor-deny-write<<EOF
#include <tunables/global>

profile k8s-apparmor-deny-write flags=(attach_disconnected) {
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
sudo apparmor_parser -rq /etc/apparmor.d/k8s-apparmor-deny-write

# confirm
sudo aa-status | grep k8s-apparmor-deny-write
  #  k8s-apparmor-deny-write
```

```yaml
# vi apparmor.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: apparmor
  name: apparmor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apparmor
  template:
    metadata:
      labels:
        app: apparmor
    spec:
      containers:
        - name: apparmor
          image: busybox:1.28
          command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 1h"]
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: k8s-apparmor-deny-write
```

```sh
kubectl create -f apparmor.yaml
# deployment.apps/apparmor created

kubectl get po
# NAME                        READY   STATUS        RESTARTS   AGE
# apparmor-79fc79dc45-8dqvd   1/1     Running       0          44s

# test
kubectl exec apparmor-79fc79dc45-8dqvd -- touch /tmp/test
# touch: /tmp/test: Permission denied
# command terminated with exit code 1
```

---

## AppArmor (killer A)

- task:
  - Some containers need to run more securely. There is an existing AppArmor profile located at `/course/9/profile` on cks7262 for this.
  - Install the AppArmor profile on node node01.
  - Connect using ssh node1 from controlplane
  - Add label `security=apparmor` to the node
  - Create a Deployment named `apparmor` in Namespace `default` with:
    - One replica of image `nginx:1-alpine`
    - NodeSelector for `security=apparmor`
    - Single container named `c1` with the `AppArmor` profile enabled only for this container
  - The Pod might not run properly with the profile enabled. Write the logs of the Pod into `/course/9/logs` on controlplane so another team can work on getting the application running.

ℹ️ Use sudo -i to become root which may be required for this question

---

- solution

```sh
# node01
ssh node01
# create aa profile
vi /etc/apparmor.d/course-9-profile
apparmor_parser -r /etc/apparmor.d/course-9-profile

aa-status | grep '<profile-name>'

# controlplane
# label
kubectl label node node01 security=apparmor --overwrite
# confirm
kubectl get node node01 --show-labels

# create deploy
k create deploy apparmor -n default --image=nginx:1-alpine --dry-run=client -o yaml > aa.yaml
```

```yaml
# vi aa.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apparmor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apparmor
  template:
    metadata:
      labels:
        app: apparmor
    spec:
      nodeSelector:
        security: apparmor
      containers:
        - name: c1
          image: nginx:1-alpine
          securityContext:
            appArmorProfile:
              type: Localhost
              localhostProfile: <profile-name>
```

```sh
kubectl apply -f aa.yaml
kubectl get pods -o wide

kubectl logs -l app=apparmor --all-containers > /course/9/logs

# confirm
cat /course/9/logs
```
