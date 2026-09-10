# CKS: Cilium - Transparent Encryption

[Back](../README.md)

- [CKS: Cilium - Transparent Encryption](#cks-cilium---transparent-encryption)
  - [Transparent Encryption](#transparent-encryption)
  - [Lab: encrypt with IPSec](#lab-encrypt-with-ipsec)
    - [Install Cilium with IPSec](#install-cilium-with-ipsec)
    - [capture encrypted traffic between nodes](#capture-encrypted-traffic-between-nodes)
  - [Lab: encrypt with wireguard](#lab-encrypt-with-wireguard)

---

## Transparent Encryption

- By default, Kubernetes does **not support pod-to-pod encryption** for network traffic.

- `Cilium` supports the **transparent encryption** of host and endpoints traffics using
  - either `IPsec (Internet Protocol Security)`
    - a set of protocols that protects data sent **over a public network** by authenticating and encrypting each packet.
  - or `WireGuard`
    - a fast, simple, and modern `virtual private network (VPN)` protocol that connects devices securely over the internet.

- ref:
  - `IPsec`: https://docs.cilium.io/en/stable/security/network/encryption-ipsec/

---

## Lab: encrypt with IPSec

### Install Cilium with IPSec

```sh
# cluster installed but not cni
kubectl get nodes
# NAME           STATUS     ROLES           AGE   VERSION
# controlplane   NotReady   control-plane   8h    v1.32.13

# ##############################
# Download
# ##############################
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

# download
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm -v cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# ##############################
# Generate PSK
# ##############################
# Generate & Import the PSK
cilium encrypt create-key --auth-algo rfc4106-gcm-aes
# IPsec key successfully created, new key SPI: 1

# confirm
kubectl -n kube-system get secrets cilium-ipsec-keys
# NAME                TYPE     DATA   AGE
# cilium-ipsec-keys   Opaque   1      8s

# ##############################
# Install
# ##############################
cilium install 1.20.1 --set encryption.enabled=true --set encryption.type=ipsec
# ℹ️  Using Cilium version 1.20.1
# 🔮 Auto-detected cluster name: kubernetes
# 🔮 Auto-detected kube-proxy has been installed

# confirm
cilium status --wait
cilium config view | grep enable-ipsec
# enable-ipsec                                      true
# enable-ipsec-key-watcher                          true
kubectl get node
# NAME           STATUS   ROLES           AGE   VERSION
# controlplane   Ready    control-plane   9h    v1.32.13
# node01         Ready    <none>          29s   v1.32.11

# validate
kubectl -n kube-system exec -ti ds/cilium -- bash
apt-get update
apt-get -y install tcpdump

cilium-dbg encrypt status
# Encryption: IPsec
# Decryption interface(s): ens33
# Keys in use: 4
# Max Seq. Number: 0x4/0xffffffffffffffff
# Errors: 0

# Check that traffic is encrypted
tcpdump -ni ens33 esp
# tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
# listening on ens33, link-type EN10MB (Ethernet), snapshot length 262144 bytes
# 00:15:32.538942 IP 192.168.10.151 > 192.168.10.150: ESP(spi=0x00000001,seq=0x18), length 136
# 00:15:32.539099 IP 192.168.10.150 > 192.168.10.151: ESP(spi=0x00000001,seq=0x17), length 136
# 00:15:33.153115 IP 192.168.10.150 > 192.168.10.151: ESP(spi=0x00000001,seq=0x18), length 136
# 00:15:33.153944 IP 192.168.10.151 > 192.168.10.150: ESP(spi=0x00000001,seq=0x19), length 136
# 00:15:37.657902 IP 192.168.10.151 > 192.168.10.150: ESP(spi=0x00000001,seq=0x1a), length 136
# 00:15:37.658116 IP 192.168.10.150 > 192.168.10.151: ESP(spi=0x00000001,seq=0x19), length 136
```

---

### capture encrypted traffic between nodes

```sh
kubectl get node --show-labels
# NAME           STATUS   ROLES           AGE     VERSION    LABELS
# controlplane   Ready    control-plane   9h      v1.32.13   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=controlplane,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=
# node01         Ready    <none>          33m     v1.32.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node01,kubernetes.io/os=linux
# node02         Ready    <none>          4m27s   v1.32.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node02,kubernetes.io/os=linux

# create curl-test pod;
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: curl-test
spec:
  containers:
  - name: curl-test
    image: alpine/curl
    command: ['sh', '-c', 'sleep 3600']
  nodeSelector:
    kubernetes.io/hostname: node01
EOF
# pod/curl-test created

# create app-target pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-target
spec:
  containers:
  - name: app-target
    image: nginx
  nodeSelector:
    kubernetes.io/hostname: node02
EOF
# pod/app-target created

kubectl get po -o wide
# NAME         READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE   READINESS GATES
# app-target   1/1     Running   0          2m26s   10.0.2.125   node02   <none>           <none>
# curl-test    1/1     Running   0          9s      10.0.1.17    node01   <none>           <none>
```

- monitor traffic

```sh
# terminal 1
kubectl -n kube-system exec -ti ds/cilium -- bash
apt-get update
apt-get -y install tcpdump

tcpdump -n -i ens33 esp
# tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
# listening on ens33, link-type EN10MB (Ethernet), snapshot length 262144 bytes
# 01:02:42.623554 IP 192.168.10.151 > 192.168.10.152: ESP(spi=0x00000001,seq=0x10c), length 136
# 01:02:42.623554 IP 192.168.10.152 > 192.168.10.151: ESP(spi=0x00000001,seq=0x107), length 1032
# 01:02:42.623599 IP 192.168.10.151 > 192.168.10.152: ESP(spi=0x00000001,seq=0x10c), length 136
# 01:02:42.623685 IP 192.168.10.152 > 192.168.10.151: ESP(spi=0x00000001,seq=0x107), length 1032
# 01:02:42.623994 IP 192.168.10.151 > 192.168.10.152: ESP(spi=0x00000001,seq=0x10d), length 136
```

- create traffic

```sh
# terminal 2
TARGET_IP=$(kubectl get pod app-target -o jsonpath='{.status.podIP}')

kubectl exec curl-test -- curl --max-time 5 "http://${TARGET_IP}"
```

- clean up

```sh
kubectl delete po --all
```

---

## Lab: encrypt with wireguard
