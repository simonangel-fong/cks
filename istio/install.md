# CKS: Istio - Install

[Back](../README.md)

- [CKS: Istio - Install](#cks-istio---install)
  - [Install](#install)

---

## Install

- minimal

```sh
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100   101  100   101    0     0    541      0 --:--:-- --:--:-- --:--:--   543
# 100  5124  100  5124    0     0  15511      0 --:--:-- --:--:-- --:--:-- 15511

# Downloading istio-1.31.0 from https://github.com/istio/istio/releases/download/1.31.0/istio-1.31.0-linux-amd64.tar.gz ...

# Istio 1.31.0 download complete!

# The Istio release archive has been downloaded to the istio-1.31.0 directory.

# To configure the istioctl client tool for your workstation,
# add the /home/ubuntuadmin/istio-1.31.0/bin directory to your environment path variable with:
#          export PATH="$PATH:/home/ubuntuadmin/istio-1.31.0/bin"

# Begin the Istio pre-installation check by running:
#          istioctl x precheck

# Try Istio in ambient mode
#         https://istio.io/latest/docs/ambient/getting-started/
# Try Istio in sidecar mode
#         https://istio.io/latest/docs/setup/getting-started/
# Install guides for ambient mode
#         https://istio.io/latest/docs/ambient/install/
# Install guides for sidecar mode
#         https://istio.io/latest/docs/setup/install/

# Need more information? Visit https://istio.io/latest/docs/

# Add the istioctl client to your path
cd istio-1.31.0
export PATH=$PWD/bin:$PATH

istioctl version
# Istio is not present in the cluster: no running Istio pods in namespace "istio-system"
# client version: 1.31.0

istioctl install --set profile=demo -y
#         |\
#         | \
#         |  \
#         |   \
#       /||    \
#      / ||     \
#     /  ||      \
#    /   ||       \
#   /    ||        \
#  /     ||         \
# /______||__________\
# ____________________
#   \__       _____/
#      \_____/

# ❗ detected Calico CNI with 'bpfConnectTimeLoadBalancing=TCP'; this must be set to 'bpfConnectTimeLoadBalancing=Disabled' in the Calico configuration
# ✔ Istio core installed ⛵️
# ✔ Istiod installed 🧠
# ✔ Egress gateways installed 🛫
# ✔ Ingress gateways installed 🛬
# ✔ Installation complete

# confirm
kubectl get pods -n istio-system
# NAME                                   READY   STATUS    RESTARTS   AGE
# istio-egressgateway-6dbc4d98b-ntzl9    1/1     Running   0          26s
# istio-ingressgateway-b99954cfb-cf8xl   1/1     Running   0          26s
# istiod-56b5d6bb69-22zr9                1/1     Running   0          36s

istioctl version
# client version: 1.31.0
# control plane version: 1.31.0
# data plane version: 1.31.0 (2 proxies)
```