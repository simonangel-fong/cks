# CKS: Pod security context - Capabilities

[back](../README.md)

- [CKS: Pod security context - Capabilities](#cks-pod-security-context---capabilities)
  - [Linux Capabilities](#linux-capabilities)
    - [Common Capabilities](#common-capabilities)
    - [Common commands](#common-commands)
    - [Declarative](#declarative)
  - [Lab: capabilities](#lab-capabilities)

---

## Linux Capabilities

- Traditional Model
  - `Processes` on a Unix-like system run primarily with the **permissions** of
    - either a `user account` with **limited** privilege
    - or with `root permissions` with **unlimited** privilege

- Granular Model
  - `Linux capabilities`
    - split the all-powerful root **user's privileges** into smaller, distinct **units** so programs only get the exact permissions they need.
      - allow binaries executed by **non-root users** to perform **privileged operations** without providing them all root permissions.
    - Least Privilege
      - can assign a **single capability** without giving a program full root access.
      - e.g., opening low-numbered network ports

- example: `ping`
  - `ping` command: uses raw sockets to send and receive ICMP packets.
  - given only the `cap_net_raw` capability, which is the minimum required to send and receive ICMP packets.
    - even a **non-privileged user** will be able to run it without any admin privileges.

  ```sh
  getcap /usr/bin/ping
  /usr/bin/ping cap_net_raw=ep
  ```

---

### Common Capabilities

| Capabilities         | Description                          |
| -------------------- | ------------------------------------ |
| CAP_NET_BIND_SERVICE | Bind to ports <1024                  |
| CAP_NET_RAW          | Use raw sockets                      |
| CAP_SYS_TIME         | Modify system clock                  |
| CAP_SYS_ADMIN        | Perform various administrative tasks |
| CAP_DAC_OVERRIDE     | Bypass file permissions              |

---

### Common commands

| Command                                         | Description                                            |
| ----------------------------------------------- | ------------------------------------------------------ |
| setcap cap_net_bind_service=+ep /usr/sbin/nginx | Assigns specific capabilities to a binary file.        |
| getcap                                          | Inspects the capabilities assigned to a specific file. |

---

### Declarative

```yaml
kind: Pod
spec:
  containers:
    - name: sec-ctx-4
      securityContext:
        capabilities:
          add: ["NET_ADMIN", "SYS_TIME"]
          drop:
            - ALL
```

- `add`: grants specific capabilities
  - Only **add** the capabilities application **actually needed**.
- `drop`: removes capabilities to minimize security risks.
  - Use `drop: ["ALL"]` First, Then explicitly add only required capabilities.

---

## Lab: capabilities

- Normal Pod

```sh
# Create Normal Pod
kubectl run normal-pod --image=busybox -- sleep 36000
# pod/normal-pod created

kubectl exec -it normal-pod -- sh
cat /proc/1/status | grep CapEff
# CapEff: 00000000a80425fb

# default cap
capsh --decode=00000000a80425fb
# 0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap

```

- Capability Pod

```sh
cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod-1
spec:
 containers:
 - name: demo
   image: busybox
   command: ["sleep","36000"]
   securityContext:
      capabilities:
        add: ["NET_ADMIN", "SYS_TIME"]
EOF
# pod/capabilities-pod-1 created

kubectl exec -it capabilities-pod-1 -- sh
cat /proc/1/status | grep CapEff
# CapEff: 00000000aa0435fb

# default cap + 2 caps
capsh --decode=00000000aa0435fb
# 0x00000000aa0435fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_admin,cap_net_raw,cap_sys_chroot,cap_sys_time,cap_mknod,cap_audit_write,cap_setfcap
```

- Capability Pod drop all

```sh
cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod-2
spec:
 containers:
 - name: demo-2
   image: busybox
   command: ["sleep","36000"]
   securityContext:
      capabilities:
        add: ["NET_ADMIN", "SYS_TIME"]
        drop:
        - ALL
EOF
# pod/capabilities-pod-2 created

kubectl exec -it capabilities-pod-2 -- sh
cat /proc/1/status | grep CapEff
# CapEff: 0000000002001000

# only 2 caps
capsh --decode=0000000002001000
# 0x0000000002001000=cap_net_admin,cap_sys_time
```
