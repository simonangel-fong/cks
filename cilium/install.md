# CKS: Cilium - install

[Back](../README.md)

- [CKS: Cilium - install](#cks-cilium---install)
  - [Install](#install)

---

## Install

- after init cluster by kubeadm

```sh
kubectl get nodes
# NAME           STATUS     ROLES           AGE   VERSION
# controlplane   NotReady   control-plane   34s   v1.32.13
```

- install cilium with cli

```sh
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

# download
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
#   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
# 100 72.6M  100 72.6M    0     0  20.3M      0  0:00:03  0:00:03 --:--:-- 30.4M
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
#   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
# 100    92  100    92    0     0    368      0 --:--:-- --:--:-- --:--:--   368

sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
# cilium-linux-amd64.tar.gz: OK

sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
# cilium
rm -v cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
# removed 'cilium-linux-amd64.tar.gz'
# removed 'cilium-linux-amd64.tar.gz.sha256sum'

cilium install
# ℹ️  Using Cilium version 1.20.1
# 🔮 Auto-detected cluster name: kubernetes
# 🔮 Auto-detected kube-proxy has been installed

cilium status --wait
#     /¯¯\
#  /¯¯\__/¯¯\    Cilium:             OK
#  \__/¯¯\__/    Operator:           OK
#  /¯¯\__/¯¯\    Envoy DaemonSet:    OK
#  \__/¯¯\__/    Hubble Relay:       disabled
#     \__/       ClusterMesh:        disabled

# DaemonSet              cilium                   Desired: 1, Ready: 1/1, Available: 1/1
# DaemonSet              cilium-envoy             Desired: 1, Ready: 1/1, Available: 1/1
# Deployment             cilium-operator          Desired: 1, Ready: 1/1, Available: 1/1
# Containers:            cilium                   Running: 1
#                        cilium-envoy             Running: 1
#                        cilium-operator          Running: 1
#                        clustermesh-apiserver
#                        hubble-relay
# Cluster Pods:          2/2 managed by Cilium
# Helm chart version:    1.20.1
# Image versions         cilium             quay.io/cilium/cilium:v1.20.1@sha256:ae9ea21f7427fe24bc6ea7247eb552157a1b0a431744045d3f641545ca71d11b: 1
#                        cilium-envoy       quay.io/cilium/cilium-envoy:v1.37.5-1786810558-766ccfb37260a43e9d228837aa84ce3faf9f64e7@sha256:75b8094c7127736a2ffd2dce3945e0931cb6df21b0372ff661940eca26730b91: 1
#                        cilium-operator    quay.io/cilium/operator-generic:v1.20.1@sha256:6c3885fc7b629099fdbe2a5c87869c86feb825fa18fae299eac0f61918d16ecf: 1


# confirm
kubectl get po -n kube-system | grep cilium
# cilium-envoy-dfgzv                     1/1     Running   0             19m
# cilium-envoy-dp6rb                     1/1     Running   0             9m36s
# cilium-nw7g6                           1/1     Running   0             19m
# cilium-operator-5c95486ff5-g9hm5       1/1     Running   0             19m
# cilium-xh6fg                           1/1     Running   0             9m36s

# master node become ready
kubectl get node
# NAME           STATUS   ROLES           AGE     VERSION
# controlplane   Ready    control-plane   8m29s   v1.32.13
```

- Join worker node

```sh
# control plane
sudo kubeadm token create --print-join-command

# worker node
sudo kubeadm join 192.168.10.150:6443 --token wm6x1f.d9flc6z4edn2kueh --discovery-token-ca-cert-hash sha256:b48993d...

# control plane: confirm
kubectl get node
# NAME           STATUS   ROLES           AGE     VERSION
# controlplane   Ready    control-plane   20m     v1.32.13
# node01         Ready    <none>          3m19s   v1.32.11

cilium connectivity test
# ℹ️  Single-node environment detected, enabling single-node connectivity test
# ℹ️  Monitor aggregation detected, will skip some flow validation steps
# ✨ [kubernetes] Creating namespace cilium-test-1 for connectivity check...
# ✨ [kubernetes] Deploying echo-same-node service...
# ✨ [kubernetes] Deploying DNS test server configmap...
# ✨ [kubernetes] Deploying same-node deployment...
# ✨ [kubernetes] Deploying client deployment...
# ✨ [kubernetes] Deploying client2 deployment...
# ℹ️  Skipping tests that require a node Without Cilium
# ✨ [kubernetes] Deploying ccnp deployment...
# ✨ [kubernetes] Creating namespace cilium-test-ccnp1 for connectivity check...
# ✨ [kubernetes] Creating namespace cilium-test-ccnp2 for connectivity check...
# ✨ [kubernetes] Deploying same-node deployment...
# ✨ [kubernetes] Deploying l7-lb service...
# ✨ [kubernetes] Deploying l7-lb non-L7 service...
# ...
# ✅ [cilium-test-1] All 79 tests (324 actions) successful, 58 tests skipped, 1 scenarios skipped.
```
