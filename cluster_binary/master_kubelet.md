# CKS - Master node: `kubelet`

[Back](../../index.md)

- [CKS - Master node: `kubelet`](#cks---master-node-kubelet)
  - [Kubelet - Overview](#kubelet---overview)
  - [Install `kubelet`](#install-kubelet)
  - [PKI - Kubelet certificate](#pki---kubelet-certificate)
  - [Configure kubeconfig](#configure-kubeconfig)

---

## Kubelet - Overview

Files required by the `kubelet` systemd unit:

| File                                   | Type            | Purpose                                 |
| -------------------------------------- | --------------- | --------------------------------------- |
| `/var/lib/kubelet/kubelet-config.yaml` | Configuration   | Configures the kubelet                  |
| `/var/lib/kubelet/kubeconfig`          | Kubeconfig      | Connects the kubelet to the API server  |
| `/var/lib/kubelet/controlplane.crt`    | TLS certificate | Identifies the kubelet                  |
| `/var/lib/kubelet/controlplane.key`    | Private key     | Private key for the kubelet certificate |
| `/etc/kubernetes/pki/ca.crt`           | CA certificate  | Verifies kubelet API clients            |
| `/run/containerd/containerd.sock`      | Unix socket     | Connects the kubelet to containerd      |

- Identity

| Certificate        | CN                         | O              | Purpose                                                |
| ------------------ | -------------------------- | -------------- | ------------------------------------------------------ |
| `controlplane.crt` | `system:node:controlplane` | `system:nodes` | Authenticates to the API server and serves kubelet TLS |

---

## Install `kubelet`

```sh
export K8S_VERSION=v1.35.8

cd /tmp

# ##############################
# Install kubelet
# ##############################
curl -fL -o kubelet "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kubelet"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 56.2M  100 56.2M    0     0  13.4M      0  0:00:04  0:00:04 --:--:-- 13.7M

sudo install -v -o root -g root -m 0755 kubelet /usr/local/bin/
# 'kubelet' -> '/usr/local/bin/kubelet'

kubelet --version
# Kubernetes v1.35.8
```

---

## PKI - Kubelet certificate

```sh
cd ~/pki

# ##############################
# Create cert: controlplane
# ##############################
# config file for generating a Certificate Signing Request (CSR).
cat > controlplane.conf <<'EOF'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = system:node:controlplane
O = system:nodes

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = controlplane
IP.1  = 192.168.10.180
EOF

# create private key
openssl genrsa -out controlplane.key 2048
# create csr with conf
openssl req -new -key controlplane.key -out controlplane.csr -config controlplane.conf
# sign csr with conf
openssl x509 -req -in controlplane.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out controlplane.crt -days 365 -sha256 \
  -extensions v3_ext -extfile controlplane.conf

# Certificate request self-signature ok
# subject=CN = system:node:controlplane, O = system:nodes

# confirm CN, group and SANs
openssl x509 -in controlplane.crt -noout -subject -ext subjectAltName
# subject=CN = system:node:controlplane, O = system:nodes
# X509v3 Subject Alternative Name:
#     DNS:controlplane, IP Address:192.168.10.180

# ##############################
# Install certificate and key
# ##############################
sudo mkdir -pv /var/lib/kubelet
# mkdir: created directory '/var/lib/kubelet'

sudo install -v -o root -g root -m 0644 ~/pki/controlplane.crt /var/lib/kubelet/controlplane.crt
# '/home/ubuntuadmin/pki/controlplane.crt' -> '/var/lib/kubelet/controlplane.crt'
sudo install -v -o root -g root -m 0600 ~/pki/controlplane.key /var/lib/kubelet/controlplane.key
# '/home/ubuntuadmin/pki/controlplane.key' -> '/var/lib/kubelet/controlplane.key'

```

---

## Configure kubeconfig

```sh
cd ~/pki

# ##############################
# Configure kubeconfig: kubelet
# ##############################
# set cluster
kubectl config set-cluster kubernetes \
  --server=https://192.168.10.180:6443 \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --kubeconfig=controlplane.config

# Cluster "kubernetes" set.

# set credential: controlplane
kubectl config set-credentials system:node:controlplane \
  --client-key=controlplane.key \
  --client-certificate=controlplane.crt \
  --embed-certs=true \
  --kubeconfig=controlplane.config

# User "system:node:controlplane" set.

# set default context
kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:node:controlplane \
  --kubeconfig=controlplane.config

# Context "default" created.

kubectl config use-context default --kubeconfig=controlplane.config
# Switched to context "default".


# ##############################
# Install kubeconfigs: kubelet
# ##############################
sudo mkdir -pv /var/lib/kubelet
# mkdir: created directory '/var/lib/kubelet'
sudo install -v -o root -g root -m 0600 controlplane.config /var/lib/kubelet/kubeconfig
# 'controlplane.config' -> '/var/lib/kubelet/kubeconfig'


# ##############################
# Configure kubelet
# ##############################
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
tlsCertFile: /var/lib/kubelet/controlplane.crt
tlsPrivateKeyFile: /var/lib/kubelet/controlplane.key
readOnlyPort: 0
protectKernelDefaults: true
seccompDefault: true
EOF

# ##############################
# Configure systemd unit: kubelet
# ##############################
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
  --node-ip=192.168.10.180 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ##############################
# start service
# ##############################
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
# Created symlink /etc/systemd/system/multi-user.target.wants/kubelet.service → /etc/systemd/system/kubelet.service.

sudo systemctl status kubelet --no-pager --full
# ● kubelet.service - Kubernetes Kubelet
#      Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
#      Active: active (running) since Thu 2026-09-03 17:24:56 EDT; 4s ago
#    Main PID: 7693 (kubelet)
#       Tasks: 9 (limit: 3179)
#      Memory: 18.3M (peak: 18.5M)
#         CPU: 160ms
#      CGroup: /system.slice/kubelet.service
#              └─7693 /usr/local/bin/kubelet --config=/var/lib/kubelet/kubelet-config.yaml --kubeconfig=/var/lib/kubelet/kubeconfig --container-runtime-endpoint=unix:///run/containerd/containerd.sock --register-node=true --node-ip=192.168.10.180 --v=2

# test
kubectl get nodes
# NAME           STATUS     ROLES    AGE   VERSION
# controlplane   NotReady   <none>   23s   v1.35.8

# runbook
sudo journalctl -u kubelet -b -n 20 --no-pager --output=cat
```
