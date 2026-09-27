# Practices - Daemon

[Back](../../README.md)

- [Practices - Daemon](#practices---daemon)
  - [Shortcut](#shortcut)
    - [Recap](#recap)
    - [secure docker daemon](#secure-docker-daemon)
  - [Daemon: Container Runtime sandboxed](#daemon-container-runtime-sandboxed)
  - [Docker: config(killer A)](#docker-configkiller-a)
  - [Sandbox (killer A)](#sandbox-killer-a)
  - [Secure Docker: group](#secure-docker-group)

---

## Shortcut

| Command           | desc               |
| ----------------- | ------------------ |
| `dockerd`         | show log           |
| `dockerd --debug` | show debug logging |

- Docker Security
  - You need to be aware of `Docker Daemon` Security + `Dockerfile` security **best practices**.
  - Example Scenarios:
    1. Analyze the Dockerfile and fix 5 security issues.
    2. Disable Docker Daemon to listen on 2375
       - know the config file, can be systemd, can be json config file
    3. Make Docker Daemon Secure
    4. Remove user from docker group.

---

### Recap

- By default, Docker daemon can be accessible within the same host via `/var/run/docker.socket`
- Docker daemon can be configured to accese via `IP:2375`
  - external entity can acces Docker daemon via ip and port

```sh
# unencrypted
export DOCKER_HOST="tcp://192.168.1.10:2375"
# encrypted
export DOCKER_HOST="tcp://192.168.1.10:2376"
docker ps

# must be encrypted
dockerd --debug --host=tcp://192.168.1.10:2376 \
  --tls=true    \
  --tlscert=/var/docker/server.pem  \
  --tlskey=/var/docker/serverkey.pem
```

- default config file:
- `/etc/docker/daemon.json`

---

### secure docker daemon

- Enabling Certificate-Based Authentication

- Docker host side

```json
{
  "debug": true,
  "hosts": ["tcp://192.168.1.10:2376"],
  "tls": true,
  "tlscert": "/var/docker/server.pem",
  "tlskey": "/var/docker/serverkey.pem",
  "tlsverify": "true",
  "tlscacert": "/var/docker/caserver.pem"
}
```

```sh
# set env var
export DOCKER_TLS=true
# tls port
export DOCKER_HOST="tcp://192.168.1.10:2376"
```

---

- client side:

```sh
export DOCKER_HOST="tcp://192.168.1.10:2376"
export DOCKER_TLS_VERIFY="true"

# access with cert
docker --tlscert=<> --tlskey=<> --tlscacert=<>

```

---

## Daemon: Container Runtime sandboxed

- ref: https://kubernetes.io/docs/concepts/containers/runtime-class/

- task:
  - existing CIS runtime onfig: /etc/containerd/config.toml
  - create runtime class named `gvisor` for `runsc`
  - create a pod named `pod-sandbox` using `nginx` image and `gvisor` runtime

---

- solution:

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
  name: pod-sandbox
spec:
  runtimeClassName: gvisor
  containers:
    - name: pod-sandbox
      image: nginx
```

```sh
k apply -f pod-sandbox.yaml
k get po
# NAME          READY   STATUS    RESTARTS   AGE
# pod-sandbox   1/1     Running   0          12m

kubectl describe pod/pod-sandbox | grep gvisor
# Runtime Class Name:  gvisor

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

---

## Docker: config(killer A)

- task
  - Docker containers should run more isolated from each other by disabling inter-container communication.
  - Add `"icc": false` to the Docker config and ensure the Docker daemon is using the updated settings
  - Create two Docker containers named container1 and container2 which should
    - have image `nginx:1-alpine`
    - restart always
    - keep running in the background
  - As a result, the containers should not be able to ping each other on their IP addresses.

ℹ️ Run all Docker commands as root. Use sudo -i to become root

---

- solution

```sh
sudo -i

mkdir -p /etc/docker
vi /etc/docker/daemon.json
# add
# {"icc": false},

systemctl restart docker
systemctl is-active docker

# confirm
docker network inspect bridge | grep enable_icc

docker run -d --name container1 --restart always nginx:1-alpine
docker run -d --name container2 --restart always nginx:1-alpine

# confirm
docker ps

# get ip
docker inspect container2
ssh cks4024
docker exec container1 ping -c 3 -W 1 "<container2_ip>
```

---

## Sandbox (killer A)

- task:
  - Team purple wants to run some of their workloads more securely. Worker node node01 is already configured so that containerd supports the `runsc/gvisor` runtime.
  - Connect to the worker node using ssh node01
  - Create a RuntimeClass named `gvisor` with handler `runsc`
  - Create a Pod that uses the RuntimeClass. The Pod should be in Namespace `team-purple`, named `gvisor-test` and of image `nginx:1-alpine`
  - Ensure the Pod only ever runs on a node named node01
  - Write the output of the `dmesg` command of the successfully started Pod into `/course/10/gvisor-test-dmesg`

---

- solution

```yaml
# vi rc.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

```sh
# create runtimeclass
k apply -f rc.yaml
k get runtimeclass

# create po
k run gvisor-test -n team-purple --image=nginx:1-alpine --dry-run=client -o yaml > pod.yaml

vi pod.yaml
```

```yaml
# vi pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-test
  namespace: team-purple
spec:
  runtimeClassName: gvisor
  nodeName: node01
  containers:
    - name: gvisor-test
      image: nginx:1-alpine
```

```sh
k apply -f pod.yaml
k get po -n team-purple  -o wide

k exec -it gvisor-test -- dmesg > /course/10/gvisor-test-dmesg

# confirm
cat /course/10/gvisor-test-dmesg
```

---

## Secure Docker: group

- task:
  - Docker group and TCP access:
    - A user named developer belongs to the docker group. Remove that membership
    - Stop the Docker daemon from accepting TCP connections.

- setup env:

```sh
sudo -i
useradd -m developer
id developer
# uid=1003(developer) gid=1003(developer) groups=1003(developer)
usermod -aG docker developer
getent group docker
# docker:x:1000:root,ubuntuadmin,developer
id developer
# uid=1003(developer) gid=1003(developer) groups=1003(developer),1000(docker)

newgrp docker

sudo vi /lib/systemd/system/docker.service
# add ExecStart:
# -H tcp://0.0.0.0:2375
# or
# -H fd://0.0.0.0:2375

sudo systemctl daemon-reload
sudo systemctl restart docker

```

---

- solution

```sh
# ###########################
# remove user
# ###########################
# remove user
gpasswd -d developer docker
# Removing user developer from group docker

# confirm
getent group docker
# docker:x:1000:root,ubuntuadmin

# ###########################
# Stop TCP connections
# ###########################
# find service file
sudo systemctl status docker
# ● docker.service - Docker Application Container Engine
#      Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-26 08:12:20 EDT; 9s ago

sudo vi /lib/systemd/system/docker.service
# Remove any -H tcp://... or -H fd://...

sudo systemctl daemon-reload
sudo systemctl restart docker
# confirm
sudo systemctl status docker

```
