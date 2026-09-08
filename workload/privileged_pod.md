# CKS: pod - Privileged Pods

[Back](../README.md)

- [CKS: pod - Privileged Pods](#cks-pod---privileged-pods)
  - [Privileged Pods](#privileged-pods)
    - [Declarative](#declarative)
    - [Imperative command](#imperative-command)
  - [Lab: priviliged pods](#lab-priviliged-pods)
  - [Lab: privileged deployment](#lab-privileged-deployment)

---

## Privileged Pods

- By default, enforces strong **security boundaries** to isolate `containers` from the `host system` and from each other.

- `privileged pod`
  - a pod that **bypasses standard container isolation mechanisms**, giving its processes nearly unrestricted **access to the underlying host node's kernel and resources**.

- Common Use Cases
  - **System-level** and **infrastructure-level** workloads.
  - **Network plugins** (CNIs), **cluster storage drivers**, and **node monitoring** or **security auditing agents** that genuinely need host-level interaction.

- **IMPORTANT**:
  - `Privileged containers` are given **all Linux capabilities**, including capabilities that they don't require.
  - In most cases, **should avoid** using `privileged containers`, and instead **grant the specific capabilities** required by your container using the capabilities field in the `securityContext` field

---

### Declarative

```yaml
---
# pod
kind: Pod
spec:
  containers:
    - image: busybox
      securityContext:
        privileged: true
---
# deployment
```

---

### Imperative command

```sh
kubectl run pod_name --image=busybox --privileged
```

---

## Lab: priviliged pods

```sh
# ##############################
# non-privileged pod
# ##############################

# create non-privileged pod
kubectl run non-privileged --image=busybox -- sleep 36000
# pod/non-privileged created

# confirm
kubectl exec -it non-privileged -- sh

# list devices
ls /dev
# core             mqueue           pts              stderr           termination-log  zero
# fd/               null             random           stdin            tty
# full             ptmx             shm              stdout           urandom

# show the kernel ring buffer
dmesg
# dmesg: klogctl: Operation not permitted

# list fdisk partitions
fdisk -l
# return none


# ##############################
# privileged pod
# ##############################
# create privileged pod
kubectl run privileged-pod --image=busybox --privileged -- sleep 36000
# pod/privileged-pod created

# confirm
kubectl exec -it privileged-pod -- sh

# list devices
ls /dev
# autofs           loop4            stderr           tty3             tty55            ttyS22           vcs4
# bsg              loop5            stdin            tty30            tty56            ttyS23           vcs5
# btrfs-control    loop6            stdout           tty31            tty57            ttyS24           vcs6
# bus              loop7            termination-log  tty32            tty58            ttyS25           vcsa
# core             loop8            tty              tty33            tty59            ttyS26           vcsa1
# cpu              loop9            tty0             tty34            tty6             ttyS27           vcsa2
# cpu_dma_latency  mapper           tty1             tty35            tty60            ttyS28           vcsa3
# cuse             mcelog           tty10            tty36            tty61            ttyS29           vcsa4
# dma_heap         mem              tty11            tty37            tty62            ttyS3            vcsa5
# dri              mqueue           tty12            tty38            tty63            ttyS30           vcsa6
# ecryptfs         net              tty13            tty39            tty7             ttyS31           vcsu
# fb0              null             tty14            tty4             tty8             ttyS4            vcsu1
# ...

# show the kernel ring buffer
dmesg
dmesg
# [    0.000000] Linux version 6.14.0-37-generic (buildd@lcy02-amd64-031) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2 (Ubuntu 6.14.0-37.37~24.04.1-generic 6.14.11)
# [    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.14.0-37-generic root=UUID=fb2f90b1-7a15-494e-a75a-9fc180bab0a2 ro quiet splash
# [    0.000000] KERNEL supported cpus:
# [    0.000000]   Intel GenuineIntel
# [    0.000000]   AMD AuthenticAMD
# [    0.000000]   Hygon HygonGenuine
# [    0.000000]   Centaur CentaurHauls
# [    0.000000]   zhaoxin   Shanghai
# [    0.000000] BIOS-provided physical RAM map:
# [    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009e7ff] usable
# [    0.000000] BIOS-e820: [mem 0x000000000009e800-0x000000000009ffff] reserved
# [    0.000000] BIOS-e820: [mem 0x00000000000dc000-0x00000000000fffff] reserved
# [    0.000000] BIOS-e820: [mem 0x0000000000100000-0x000000007fedffff] usable
# [    0.000000] BIOS-e820: [mem 0x000000007fee0000-0x000000007fefefff] ACPI data
# [    0.000000] BIOS-e820: [mem 0x000000007feff000-0x000000007fefffff] ACPI NVS
# [    0.000000] BIOS-e820: [mem 0x000000007ff00000-0x000000007fffffff] usable
# [    0.000000] BIOS-e820: [mem 0x00000000f0000000-0x00000000f7ffffff] reserved
# ...

# list fdisk partitions
fdisk -l
# Disk /dev/sda: 30.0G, 32212254720 bytes, 62914560 sectors
# 3900 cylinders, 256 heads, 63 sectors/track
# Units: cylinders of 16128 * 512 = 8257536 bytes

# Device  Boot StartCHS    EndCHS        StartLBA     EndLBA    Sectors  Size Id Type
# /dev/sda1    0,0,2       1023,255,63          1   62914559   62914559 29.9G ee EFI GPT
```

- clean up

```sh
kubectl delete pod non-privileged
kubectl delete pod privileged-pod
```

---

## Lab: privileged deployment

```sh
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: privileged-deployment
  namespace: default
  labels:
    app: privileged-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: privileged-app
  template:
    metadata:
      labels:
        app: privileged-app
    spec:
      containers:
      - name: privileged-container
        image: ubuntu:latest
        command: ["/bin/bash", "-c", "--"]
        args: ["while true; do sleep 30; done;"]
        # Essential block for elevated permissions
        securityContext:
          privileged: true
EOF

kubectl get deploy
# NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
# privileged-deployment   1/1     1            1           36s

kubectl get po -l app=privileged-app
# NAME                                    READY   STATUS    RESTARTS   AGE
# privileged-deployment-b8ffc679c-7kr47   1/1     Running   0          106s

# confirm
kubectl exec -it privileged-deployment-b8ffc679c-7kr47 -- dmesg
# [    0.000000] Linux version 6.14.0-37-generic (buildd@lcy02-amd64-031) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2 (Ubuntu 6.14.0-37.37~24.04.1-generic 6.14.11)
# [    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.14.0-37-generic root=UUID=fb2f90b1-7a15-494e-a75a-9fc180bab0a2 ro quiet splash
# [    0.000000] KERNEL supported cpus:
# [    0.000000]   Intel GenuineIntel
# [    0.000000]   AMD AuthenticAMD
# [    0.000000]   Hygon HygonGenuine
# [    0.000000]   Centaur CentaurHauls
# [    0.000000]   zhaoxin   Shanghai
# [    0.000000] BIOS-provided physical RAM map:
# [    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009e7ff] usable
# [    0.000000] BIOS-e820: [mem 0x000000000009e800-0x000000000009ffff] reserved
# [    0.000000] BIOS-e820: [mem 0x00000000000dc000-0x00000000000fffff] reserved
# [    0.000000] BIOS-e820: [mem 0x0000000000100000-0x000000007fedffff] usable
# [    0.000000] BIOS-e820: [mem 0x000000007fee0000-0x000000007fefefff] ACPI data
# [    0.000000] BIOS-e820: [mem 0x000000007feff000-0x000000007fefffff] ACPI NVS
```
