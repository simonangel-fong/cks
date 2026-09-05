# CKS - Master node: `kube-proxy`

[Back](../../index.md)

- [CKS - Master node: `kube-proxy`](#cks---master-node-kube-proxy)
  - [Kube-proxy - Overview](#kube-proxy---overview)
    - [Required files](#required-files)
    - [Identity](#identity)
  - [Install `kube-proxy`](#install-kube-proxy)
  - [PKI - kube-proxy certificate](#pki---kube-proxy-certificate)
  - [Configure kubeconfig](#configure-kubeconfig)
  - [Configure `kube-proxy`](#configure-kube-proxy)

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

```sh
cd /tmp

export K8S_VERSION=v1.35.8

curl -fL -o kube-proxy \
  "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kube-proxy"

sudo install -v -o root -g root -m 0755 kube-proxy /usr/local/bin/
# 'kube-proxy' -> '/usr/local/bin/kube-proxy'

kube-proxy --version
# Kubernetes v1.35.8
```

---

## PKI - kube-proxy certificate

```sh
cd ~/pki

gen_client kube-proxy "/CN=system:kube-proxy/O=system:node-proxier"
# Certificate request self-signature ok
# subject=CN = system:kube-proxy, O = system:node-proxier
# removed 'kube-proxy.csr'

ls -l kube-proxy.crt kube-proxy.key
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin ... kube-proxy.crt
# -rw------- 1 ubuntuadmin ubuntuadmin ... kube-proxy.key

openssl x509 -in kube-proxy.crt -noout -subject
# subject=CN = system:kube-proxy, O = system:node-proxier
```

---

## Configure kubeconfig

```sh
cd ~/pki

kubectl config set-cluster kubernetes \
  --server=https://192.168.10.180:6443 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=kube-proxy.config
# Cluster "kubernetes" set.

kubectl config set-credentials system:kube-proxy \
  --client-key=kube-proxy.key \
  --client-certificate=kube-proxy.crt \
  --embed-certs=true \
  --kubeconfig=kube-proxy.config
# User "system:kube-proxy" set.

kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.config

# Context "default" created.

kubectl config use-context default --kubeconfig=kube-proxy.config
# Switched to context "default".

sudo mkdir -pv /var/lib/kube-proxy
# mkdir: created directory '/var/lib/kube-proxy'

sudo install -v -o root -g root -m 0600 kube-proxy.config \
  /var/lib/kube-proxy/kube-proxy.config

# 'kube-proxy.config' -> '/var/lib/kube-proxy/kube-proxy.config'
```

---

## Configure `kube-proxy`

```sh
cat <<'EOF' | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kube-proxy.config
mode: iptables
clusterCIDR: 10.244.0.0/16
hostnameOverride: controlplane
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
After=kube-apiserver.service

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
#      Active: active (running)
```

---
