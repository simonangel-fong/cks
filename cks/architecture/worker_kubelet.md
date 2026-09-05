# CKS - Worker node: `kubelet`

[Back](../../index.md)

- [CKS - Worker node: `kubelet`](#cks---worker-node-kubelet)
  - [Kubelet - Overview](#kubelet---overview)
    - [Required files](#required-files)
    - [Identity](#identity)
  - [Install `kubelet`](#install-kubelet)
  - [Install credentials](#install-credentials)
  - [Configure `kubelet`](#configure-kubelet)
  - [Verify node registration](#verify-node-registration)

---

## Kubelet - Overview

### Required files

Files required by the `kubelet` systemd unit:

| File                                   | Type            | Purpose                                 |
| -------------------------------------- | --------------- | --------------------------------------- |
| `/var/lib/kubelet/kubelet-config.yaml` | Configuration   | Configures the kubelet                  |
| `/var/lib/kubelet/kubeconfig`          | Kubeconfig      | Connects kubelet to the API server      |
| `/var/lib/kubelet/node01.crt`          | TLS certificate | Identifies the node01 kubelet           |
| `/var/lib/kubelet/node01.key`          | Private key     | Private key for the kubelet certificate |
| `/etc/kubernetes/pki/ca.crt`           | CA certificate  | Verifies kubelet API clients            |
| `/run/containerd/containerd.sock`      | Unix socket     | Connects kubelet to containerd          |

### Identity

| Certificate  | CN                   | O              | Purpose                                                |
| ------------ | -------------------- | -------------- | ------------------------------------------------------ |
| `node01.crt` | `system:node:node01` | `system:nodes` | Authenticates to the API server and serves kubelet TLS |

---

## Install `kubelet`

Run this section on `node01`.

```sh
export K8S_VERSION=v1.35.8

cd /tmp

curl -fL -o kubelet "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kubelet"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 56.2M  100 56.2M    0     0  6843k      0  0:00:08  0:00:08 --:--:-- 7197k

sudo install -v -o root -g root -m 0755 kubelet /usr/local/bin/
# 'kubelet' -> '/usr/local/bin/kubelet'

kubelet --version
# Kubernetes v1.35.8
```

---

## Install credentials

Run this section on `node01`.

```sh
cd ~/worker-bootstrap

sudo mkdir -pv /var/lib/kubelet /etc/kubernetes/pki
# mkdir: created directory '/var/lib/kubelet'
# mkdir: created directory '/etc/kubernetes'
# mkdir: created directory '/etc/kubernetes/pki'

sudo install -v -o root -g root -m 0644 node01.crt /var/lib/kubelet/node01.crt
# 'node01.crt' -> '/var/lib/kubelet/node01.crt'
sudo install -v -o root -g root -m 0600 node01.key /var/lib/kubelet/node01.key
# 'node01.key' -> '/var/lib/kubelet/node01.key'
sudo install -v -o root -g root -m 0644 ca.crt /etc/kubernetes/pki/ca.crt
# 'ca.crt' -> '/etc/kubernetes/pki/ca.crt'
sudo install -v -o root -g root -m 0600 kubelet.conf /var/lib/kubelet/kubeconfig
# 'kubelet.conf' -> '/var/lib/kubelet/kubeconfig'
```

---

## Configure `kubelet`

Run this section on `node01`.

```sh
cat <<'EOF' | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - 10.96.0.10
cgroupDriver: systemd
runtimeRequestTimeout: "15m"
tlsCertFile: /var/lib/kubelet/node01.crt
tlsPrivateKeyFile: /var/lib/kubelet/node01.key
readOnlyPort: 0
protectKernelDefaults: true
seccompDefault: true
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --container-runtime-endpoint=unix:///run/containerd/containerd.sock \
  --register-node=true \
  --node-ip=192.168.10.181 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
# Created symlink /etc/systemd/system/multi-user.target.wants/kubelet.service → /etc/systemd/system/kubelet.service.

sudo systemctl status kubelet --no-pager --full
# ● kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: active (running) since Thu 2026-09-03 23:49:54 EDT; 14s ago
#    Main PID: 3205 (kubelet)
#       Tasks: 13 (limit: 9373)
#      Memory: 27.5M (peak: 28.9M)
#         CPU: 1.291s
#      CGroup: /system.slice/kubelet.service
#              └─3205 /usr/local/bin/kubelet --config=/var/lib/kubelet/kubelet-config.yaml --kubeconfig=/var/lib/kubelet/kubeconfig --container-runtime-endpoint=unix:///run/containerd/containerd.sock --register-node=true --node-ip=192.168.10.181 --v=2

# Sep 03 23:50:03 node01 kubelet[3205]: I0903 23:50:03.691524    3205 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="calico-system/csi-node-driver-wnx8x"
# Sep 03 23:50:03 node01 kubelet[3205]: E0903 23:50:03.692175    3205 pod_workers.go:1324] "Error syncing pod, skipping" err="network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized" pod="calico-system/csi-node-driver-wnx8x" podUID="b1418c4b-13e8-4a44-b207-692af582b82a"
# Sep 03 23:50:04 node01 kubelet[3205]: I0903 23:50:04.728012    3205 kubelet.go:2624] "SyncLoop (PLEG): event for pod" pod="calico-system/calico-node-mlzdd" event={"ID":"a7a36d87-5de7-4ad5-ab35-18b4035970ba","Type":"ContainerStarted","Data":"ef654fec94740a730bea54b5b82bd8a9231382543daed69a4facae62d38e8995"}
# Sep 03 23:50:04 node01 kubelet[3205]: I0903 23:50:04.793957    3205 plugins.go:627] "Loaded volume plugin" pluginName="nodeagent/uds"
# Sep 03 23:50:05 node01 kubelet[3205]: I0903 23:50:05.692601    3205 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="calico-system/csi-node-driver-wnx8x"
# Sep 03 23:50:05 node01 kubelet[3205]: E0903 23:50:05.692788    3205 pod_workers.go:1324] "Error syncing pod, skipping" err="network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized" pod="calico-system/csi-node-driver-wnx8x" podUID="b1418c4b-13e8-4a44-b207-692af582b82a"
# Sep 03 23:50:07 node01 kubelet[3205]: I0903 23:50:07.692350    3205 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="calico-system/csi-node-driver-wnx8x"
# Sep 03 23:50:07 node01 kubelet[3205]: E0903 23:50:07.692529    3205 pod_workers.go:1324] "Error syncing pod, skipping" err="network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized" pod="calico-system/csi-node-driver-wnx8x" podUID="b1418c4b-13e8-4a44-b207-692af582b82a"
# Sep 03 23:50:09 node01 kubelet[3205]: I0903 23:50:09.904256    3205 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="calico-system/csi-node-driver-wnx8x"
# Sep 03 23:50:09 node01 kubelet[3205]: E0903 23:50:09.904758    3205 pod_workers.go:1324] "Error syncing pod, skipping" err="network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized" pod="calico-system/csi-node-driver-wnx8x" podUID="b1418c4b-13e8-4a44-b207-692af582b82a"

# runbook
sudo journalctl -u kubelet -b -n 20 --no-pager --output=cat
```

---

## Verify node registration

Run this section on `controlplane`.

```sh
# notready: proxy not install
kubectl get node
# NAME           STATUS     ROLES    AGE     VERSION
# controlplane   Ready      <none>   68m     v1.35.8
# node01         NotReady   <none>   8m23s   v1.35.8

kubectl get node node01 -o jsonpath='{.spec.podCIDR}{"\n"}'
# 10.244.1.0/24
```

---
