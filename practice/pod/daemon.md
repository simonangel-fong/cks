# Practices - Daemon

[Back](../../README.md)

- [Practices - Daemon](#practices---daemon)
  - [Daemon: Container Runtime sandboxed](#daemon-container-runtime-sandboxed)

---

- Docker Security
  - You need to be aware of `Docker Daemon` Security + `Dockerfile` security **best practices**.
  - Example Scenarios:
    1. Analyze the Dockerfile and fix 5 security issues.
    2. Disable Docker Daemon to listen on 2375
       - know the config file, can be systemd, can be json config file
    3. Make Docker Daemon Secure
    4. Remove user from docker group.

## Daemon: Container Runtime sandboxed

- ref: https://kubernetes.io/docs/concepts/containers/runtime-class/

```sh
# get containerd config: default handler=runc; sanbox handler=runsc
cat /etc/containerd/config.toml
# version = 2
# [plugins."io.containerd.runtime.v1.linux"]
#   shim_debug = true
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#   runtime_type = "io.containerd.runc.v2"
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
#   runtime_type = "io.containerd.runsc.v1"
```

```yaml
# vi runtime.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc # match sandbox handler
```

```sh
k apply -f runtime.yaml

k get runtimeclass
# NAME     HANDLER   AGE
# gvisor   runsc     22s
```

```yaml
# vi pod-sandbox.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: pod-sandbox
  name: pod-sandbox
spec:
  runtimeClassName: gvisor
  containers:
    - name: pod-sandbox
      image: nginx
      ports:
        - containerPort: 80
```

```sh
k apply -f pod-sandbox.yaml
k get po
# NAME          READY   STATUS    RESTARTS   AGE
# pod-sandbox   1/1     Running   0          12m

# confirm
k exec pod-sandbox -- dmesg
# [    0.000000] Starting gVisor...
# [    0.182932] Adversarially training Redcode AI...
# [    0.572213] Checking naughty and nice process list...
# [    0.996369] Rewriting operating system in Javascript...
# [    1.332897] Gathering forks...
# [    1.822389] Letting the watchdogs out...
# [    2.174501] Mounting deweydecimalfs...
# [    2.327993] Moving files to filing cabinet...
# [    2.739032] Searching for needles in stacks...
# [    3.081893] Segmenting fault lines...
# [    3.134610] Rewriting the kernel in Rust...
# [    3.534428] Ready!
```
