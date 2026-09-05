# CKS - Worker node: `kube-proxy`

[Back](../../index.md)

- [CKS - Worker node: `kube-proxy`](#cks---worker-node-kube-proxy)
  - [Kube-proxy - Overview](#kube-proxy---overview)
    - [Required files](#required-files)
    - [Identity](#identity)
  - [Install `kube-proxy`](#install-kube-proxy)
  - [Install kubeconfig](#install-kubeconfig)
  - [Configure `kube-proxy`](#configure-kube-proxy)
  - [Verify `kube-proxy`](#verify-kube-proxy)
  - [Test](#test)

---

## Kube-proxy - Overview

### Required files

Files required by the `kube-proxy` systemd unit:

| File                                         | Type          | Purpose                               |
| -------------------------------------------- | ------------- | ------------------------------------- |
| `/var/lib/kube-proxy/kube-proxy-config.yaml` | Configuration | Configures kube-proxy                 |
| `/var/lib/kube-proxy/kube-proxy.config`      | Kubeconfig    | Connects kube-proxy to the API server |

### Identity

| Certificate      | CN                  | O                     | Purpose                         |
| ---------------- | ------------------- | --------------------- | ------------------------------- |
| `kube-proxy.crt` | `system:kube-proxy` | `system:node-proxier` | Authenticates to the API server |

---

## Install `kube-proxy`

Run this section on `node01`.

```sh
export K8S_VERSION=v1.35.8

cd /tmp

curl -fL -o kube-proxy "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kube-proxy"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 41.8M  100 41.8M    0     0  28.8M      0  0:00:01  0:00:01 --:--:-- 28.8M

sudo install -v -o root -g root -m 0755 kube-proxy /usr/local/bin/
# 'kube-proxy' -> '/usr/local/bin/kube-proxy'

kube-proxy --version
# Kubernetes v1.35.8
```

---

## Install kubeconfig

Run this section on `node01`.

```sh
cd ~/worker-bootstrap

sudo mkdir -pv /var/lib/kube-proxy
# mkdir: created directory '/var/lib/kube-proxy'

sudo install -v -o root -g root -m 0600 kube-proxy.conf /var/lib/kube-proxy/kube-proxy.config
# 'kube-proxy.conf' -> '/var/lib/kube-proxy/kube-proxy.config'
```

---

## Configure `kube-proxy`

Run this section on `node01`.

```sh
cat <<'EOF' | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.config
mode: iptables
clusterCIDR: 10.244.0.0/16
hostnameOverride: node01
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/kube-proxy \
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now kube-proxy
# Created symlink /etc/systemd/system/multi-user.target.wants/kube-proxy.service → /etc/systemd/system/kube-proxy.service.

sudo systemctl status kube-proxy --no-pager --full
# ● kube-proxy.service - Kubernetes Kube Proxy
#      Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; preset: enabled)
#      Active: active (running) since Fri 2026-09-04 00:03:11 EDT; 11s ago
#    Main PID: 4722 (kube-proxy)
#       Tasks: 7 (limit: 9373)
#      Memory: 14.3M (peak: 16.6M)
#         CPU: 643ms
#      CGroup: /system.slice/kube-proxy.service
#              └─4722 /usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.yaml

# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.160580    4722 shared_informer.go:356] "Caches are synced" controller="node config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162012    4722 config.go:200] "Starting service config controller"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162034    4722 shared_informer.go:349] "Waiting for caches to sync" controller="service config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162058    4722 config.go:106] "Starting endpoint slice config controller"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162067    4722 shared_informer.go:349] "Waiting for caches to sync" controller="endpoint slice config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162081    4722 config.go:403] "Starting serviceCIDR config controller"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.162443    4722 shared_informer.go:349] "Waiting for caches to sync" controller="serviceCIDR config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.263091    4722 shared_informer.go:356] "Caches are synced" controller="serviceCIDR config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.263123    4722 shared_informer.go:356] "Caches are synced" controller="endpoint slice config"
# Sep 04 00:03:12 node01 kube-proxy[4722]: I0904 00:03:12.263091    4722 shared_informer.go:356] "Caches are synced" controller="service config"
```

---

## Verify `kube-proxy`

Run this section on `controlplane`.

```sh
# confirm cni is running
kubectl -n calico-system get pods -o wide
# NAME                                       READY   STATUS    RESTARTS      AGE   IP               NODE           NOMINATED NODE   READINESS GATES
# calico-apiserver-64d74c9474-cpphv          1/1     Running   1 (29m ago)   67m   10.244.49.73     controlplane   <none>           <none>
# calico-apiserver-64d74c9474-nxp5s          1/1     Running   1 (29m ago)   67m   10.244.49.76     controlplane   <none>           <none>
# calico-kube-controllers-5b5647977c-vsg9g   1/1     Running   1 (29m ago)   67m   10.244.49.79     controlplane   <none>           <none>
# calico-node-8z5gs                          1/1     Running   1 (29m ago)   67m   192.168.10.180   controlplane   <none>           <none>
# calico-node-mlzdd                          1/1     Running   0             15m   192.168.10.181   node01         <none>           <none>
# calico-typha-77b497cd9c-rq2x4              1/1     Running   1 (29m ago)   67m   192.168.10.180   controlplane   <none>           <none>
# csi-node-driver-4wqr9                      2/2     Running   2 (29m ago)   67m   10.244.49.75     controlplane   <none>           <none>
# csi-node-driver-wnx8x                      2/2     Running   0             15m   10.244.196.129   node01         <none>           <none>
# goldmane-5d7c56cd95-nqrpb                  1/1     Running   1 (64m ago)   67m   10.244.49.77     controlplane   <none>           <none>
# whisker-6bd9f75f44-zprzq                   2/2     Running   2 (29m ago)   67m   10.244.49.78     controlplane

kubectl get node node01
# NAME     STATUS   ROLES    AGE   VERSION
# node01   Ready    <none>   15m   v1.35.8
```

---

## Test

```sh
kubectl run web --image=nginx --overrides='{"spec": {"nodeName": "node01"}}'
# pod/web created

kubectl get po web -o wide
# NAME   READY   STATUS    RESTARTS   AGE   IP               NODE     NOMINATED NODE   READINESS GATES
# web    1/1     Running   0          15s   10.244.196.130   node01   <none>           <none>
```