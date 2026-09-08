# CKS: Fundamental - Security Context

[back](../README.md)

- [CKS: Fundamental - Security Context](#cks-fundamental---security-context)
  - [Security Context](#security-context)
    - [Common fiels](#common-fiels)
    - [Declarative](#declarative)
  - [Lab: Security context](#lab-security-context)
    - [pod with root](#pod-with-root)
    - [pod with security context (hostpath)](#pod-with-security-context-hostpath)
    - [pod with security context (emptyDir)](#pod-with-security-context-emptydir)

---

## Security Context

- If a container image was **built to run as root by default** , Kubernetes will run it as `root` unless.

- `Security Context`
  - defines the **privilege and access control** settings for a `Pod` or a `Container`.
  - can be
    - **set at the pod level**
    - **override** it for an **individual container**

- Key Settings
  - **User and Group IDs** (`runAsUser` / `runAsGroup`):
    - Controls which `user ID` runs the processes inside the container.
  - **Privileged Mode**:
    - Runs the container with **full access** to the host machine's resources, similar to a **root process outside a container**.
  - **Read-Only Root Filesystem** (`readOnlyRootFilesystem`):
    - Prevents applications from writing data to the container's root file system.
  - **Linux Capabilities**:
    - **Grants** specific root-level privileges (like binding to low-numbered ports) **without** giving full root access.
  - **Privilege Escalation** (`allowPrivilegeEscalation`):
    - Stops a process from gaining more privileges than its **parent process**.
  - **Security Modules** (`SELinux`, `AppArmor`, `Seccomp`):
    - Restricts system calls and applies custom security labels to isolate workloads.

---

### Common fiels

| Field        | Description                                                         | Use-Case                                     |
| ------------ | ------------------------------------------------------------------- | -------------------------------------------- |
| `runAsUser`  | Specifies the user ID (UID) a container's process runs as.          | run as non-root/specific users               |
| `runAsGroup` | Specifies the primary group ID (GID) a container's process runs as. | run as speific GID                           |
| `fsGroup`    | Specifies a group ID (GID) for volume-mounted files.                | control file permissions for a shared volume |

---

### Declarative

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext: # pod level
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
  volumes:
    - name: sec-ctx-vol
      emptyDir: {}
  containers:
    - name: sec-ctx-demo
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
      volumeMounts:
        - name: sec-ctx-vol
          mountPath: /data/demo
      securityContext: # container level
        allowPrivilegeEscalation: false
```

---

## Lab: Security context

### pod with root

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
 containers:
 - name: demo-container
   image: busybox:latest
   command: ["sleep", "36000"]
   volumeMounts:
    - name: host-root
      mountPath: /host
 volumes:
  - name: host-root
    hostPath:
      path: /
EOF
# pod/insecure-pod created

kubectl get pod insecure-pod
# NAME           READY   STATUS    RESTARTS   AGE
# insecure-pod   1/1     Running   0          17s

kubectl exec -it insecure-pod -- sh
id
# uid=0(root) gid=0(root) groups=0(root),10(wheel)

ls /host
# bin                 etc                 lost+found          root                srv                 var
# bin.usr-is-merged   home                media               run                 swap.img
# boot                lib                 mnt                 sbin                sys
# cdrom               lib.usr-is-merged   opt                 sbin.usr-is-merged  tmp
# dev                 lib64               proc                snap                usr

touch /host/test.txt
ls -l /host/test.txt
# -rw-r--r--    1 root     root             0 Sep  8 12:14 /host/test.txt

kubectl delete pod insecure-pod
# pod "insecure-pod" deleted
```

---

### pod with security context (hostpath)

- security context limits new file created on host volume mount

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: controlled-pod
spec:
 securityContext:
   runAsUser: 1000
   runAsGroup: 2000
   fsGroup: 3000
 containers:
 - name: demo-container
   image: busybox:latest
   command: ["sleep", "36000"]
   volumeMounts:
    - name: host-root
      mountPath: /host
 volumes:
  - name: host-root
    hostPath:
      path: /
EOF
# pod/controlled-pod created

kubectl get pod controlled-pod
# NAME             READY   STATUS    RESTARTS   AGE
# controlled-pod   1/1     Running   0          16s

kubectl exec -it controlled-pod -- sh
id
# uid=1000 gid=2000 groups=2000,3000

ls /host
# bin                 etc                 lost+found          root                srv                 var
# bin.usr-is-merged   home                media               run                 swap.img
# boot                lib                 mnt                 sbin                sys
# cdrom               lib.usr-is-merged   opt                 sbin.usr-is-merged  tmp
# dev                 lib64               proc                snap                usr

touch /host/test.txt
# touch: /host/test.txt: Permission denied
```

> /host/test.txt cannot be created because volume host-root mount on host node's root /

---

### pod with security context (emptyDir)

- security context allows new file created on emptyDir

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fsgroup-pod
spec:
 securityContext:
   runAsUser: 1000
   runAsGroup: 2000
   fsGroup: 3000
 volumes:
  - name: host-root
    emptyDir: {}
 containers:
 - name: demo-container
   image: busybox:latest
   command: ["sleep", "36000"]
   volumeMounts:
    - name: host-root
      mountPath: /host
EOF
# pod/fsgroup-pod created

kubectl exec -it fsgroup-pod -- sh
id
# uid=1000 gid=2000 groups=2000,3000

ls /host
touch /host/test.txt
ls -l /host/test.txt
# -rw-r--r--    1 1000     3000             0 Sep  8 12:20 /host/test.txt
```

> test.txt can be created because volume mount with emptyDir
