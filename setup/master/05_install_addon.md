# CKS setup: master install addon

- [CKS setup: master install addon](#cks-setup-master-install-addon)
  - [Install `helm`](#install-helm)
  - [Install CNI (Calico)](#install-cni-calico)
  - [Install metrics server](#install-metrics-server)
  - [Install `nginx ingress controller`](#install-nginx-ingress-controller)
  - [Install `etcd-client`](#install-etcd-client)
  - [Install `MetalLB`](#install-metallb)
  - [Install Isio](#install-isio)
  - [Install falco](#install-falco)
  - [install trivy](#install-trivy)
  - [Install kube-bench](#install-kube-bench)
  - [Install checkov](#install-checkov)
  - [Install bom](#install-bom)

## Install `helm`

```sh
# ##############################
# Add the Helm apt repository
# ##############################
HELM_BUILDKITE_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

sudo apt-get install curl gpg apt-transport-https --yes

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "${TMPDIR:-/tmp}/helm.gpg"

# verify key fingerprint before trusting it
if [ "$(gpg --show-keys --with-colons "${TMPDIR:-/tmp}/helm.gpg" | awk -F: '$1 == "fpr" {print $10}' | head -n 1)" != "${HELM_BUILDKITE_APT_KEY_ID}" ]; then echo "ERROR: Unexpected Helm APT key ID: potential key compromise"; exit 1; fi

cat "${TMPDIR:-/tmp}/helm.gpg" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm

helm version
```

---

## Install CNI (Calico)

```sh
# get cluster ip cidr
kubectl cluster-info dump | grep -m 1 cluster-cidr
#  "--cluster-cidr=10.244.0.0/16",

IP_POD_CIDR="10.244.0.0/16"
CALICO_VERSION="v3.32.2"

# ##############################
# Install CRDs
# ##############################
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/v1_crd_projectcalico_org.yaml"

# ##############################
# Install Tigera operator
# ##############################
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml"

# ##############################
# Override default pod CIDR (192.168.0.0/16)
# ##############################
curl -fL -o /tmp/custom-resources.yaml "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml"

sed -i "s|cidr: 192.168.0.0/16|cidr: $IP_POD_CIDR|" /tmp/custom-resources.yaml

# confirm the cidr was replaced
grep cidr /tmp/custom-resources.yaml
#         cidr: 10.244.0.0/16

# ##############################
# Install Calico
# ##############################
kubectl create -f /tmp/custom-resources.yaml

# ##############################
# Verify
# ##############################
watch -n 1 kubectl get tigerastatus

kubectl get ippools -o custom-columns=NAME:.metadata.name,CIDR:.spec.cidr
# NAME                  CIDR
# default-ipv4-ippool   10.244.0.0/16

kubectl get po -n calico-system

kubectl get node
# NAME           STATUS   ROLES           AGE   VERSION
# controlplane   Ready    control-plane   50m   v1.35.8
```

---

## Install metrics server

```sh
# ##############################
# Install metrics server
# ##############################
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl rollout status deployment metrics-server -n kube-system

# ##############################
# Install metrics server
# ##############################
kubectl get deployment metrics-server -n kube-system

kubectl top node
```

---

## Install `nginx ingress controller`

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml

# ##############################
# Verify
# ##############################
kubectl get deploy --namespace=ingress-nginx
kubectl get ingressclass
kubectl get svc --namespace=ingress-nginx
```

---

## Install `etcd-client`

```sh
sudo apt-get install etcd-client -y

etcdctl version
```

---

## Install `MetalLB`

```sh
# update config
kubectl edit configmap -n kube-system kube-proxy
# find:
# ipvs:
#   strictARP: false
# replace:
# ipvs:
#   strictARP: true

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml

# confirm
kubectl get pods -n metallb-system

# Create IPAddressPool that MetalLB can assign from.
tee ~/metallb-ip-pool.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: web-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.210-192.168.10.220
EOF

kubectl apply -f ~/metallb-ip-pool.yaml

kubectl get IPAddressPool web-pool -n metallb-system
# NAME       AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
# web-pool   true          false             ["192.168.10.210-192.168.10.220"]

# Create L2Advertisement to announce those IPs via ARP.
tee ~/metallb-l2adv.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: web-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - web-pool
EOF

kubectl apply -f ~/metallb-l2adv.yaml
# l2advertisement.metallb.io/web-l2 created

kubectl get L2Advertisement web-l2 -n metallb-system

# confirm: MetalLB assign an external IP to Nginx Gateway Service
kubectl get svc -n ingress-nginx
# NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
# ingress-nginx-controller             LoadBalancer   10.105.107.57    192.168.10.210   80:30154/TCP,443:30846/TCP   5m41s
# ingress-nginx-controller-admission   ClusterIP      10.101.217.192   <none>           443/TCP                      5m41s
```

---

## Install Isio

```sh
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.31.0
export PATH=$PWD/bin:$PATH

istioctl install --set profile=demo -y

kubectl get pods -n istio-system

istioctl version
```

---

## Install falco

```sh
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

# update repo list
sudo bash -c 'cat << EOF > /etc/apt/sources.list.d/falcosecurity.list
deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main
EOF'

sudo apt-get update -y

sudo apt install -y dkms make linux-headers-$(uname -r)
sudo apt-get install -y dialog

sudo apt-get install -y falco
# 2
# 2

sudo systemctl status falco-modern-bpf.service --no-page

```

---

## install trivy

```sh
sudo apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

trivy version
# Version: 0.74.0
```

---

## Install kube-bench

```sh
# Download
curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.16.0/kube-bench_0.16.0_linux_amd64.deb -o /tmp/kube-bench.deb

# Install
sudo apt install /tmp/kube-bench.deb

# Verify
kube-bench version
```

---

## Install checkov

```sh
sudo apt update && sudo apt install python3-pip python3.12-venv -y

python3 -m venv ~/cks/.venv
source ~/cks/.venv/bin/activate
pip install checkov

# confirm
checkov --version
```

---

## Install bom

```sh
curl -L \
  https://github.com/kubernetes-sigs/bom/releases/download/v0.7.1/bom-amd64-linux \
  -o /tmp/bom

sudo install -m 0755 /tmp/bom /usr/local/bin/bom

bom version
```