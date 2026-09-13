# CKS setup: master install addon

- [CKS setup: master install addon](#cks-setup-master-install-addon)
  - [Install `helm`](#install-helm)
  - [Install CNI (Calico)](#install-cni-calico)
  - [Install metrics server](#install-metrics-server)
  - [Install `nginx ingress controller`](#install-nginx-ingress-controller)
  - [Install `etcd-client`](#install-etcd-client)
  - [Review installed releases](#review-installed-releases)

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
# version.BuildInfo{Version:"v4.3.0", GitCommit:"bec5b06ed841fe5269972d864d5177944fd5970f", GitTreeState:"clean", GoVersion:"go1.27.1", KubeClientVersion:"v1.37"}
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
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/operator-crds.yaml"

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
# NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
# apiserver   True        False         False      44s
# calico      True        False         False      39s
# goldmane    True        False         False      19s
# ippools     True        False         False      109s
# whisker     True        False         False      39s

kubectl get ippools -o custom-columns=NAME:.metadata.name,CIDR:.spec.cidr
# NAME                  CIDR
# default-ipv4-ippool   10.244.0.0/16

kubectl get node
# NAME           STATUS   ROLES           AGE   VERSION
# controlplane   Ready    control-plane   50m   v1.35.8
```

---

## Install metrics server

```sh
METRICS_VERSION="3.14.1"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "$METRICS_VERSION" \
  --namespace kube-system \
  --set 'args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}' \
  --wait

# ##############################
# Verify
# ##############################
kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# metrics-server   1/1     1            1           68s

kubectl top node
# NAME           CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
# controlplane   182m         9%       1543Mi          40%
```

---

## Install `nginx ingress controller`

```sh
INGRESS_VERSION="4.14.1"

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version "$INGRESS_VERSION" \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --wait

# ##############################
# Verify
# ##############################
kubectl get deploy --namespace=ingress-nginx
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# ingress-nginx-controller   1/1     1            1           16m

kubectl get svc --namespace=ingress-nginx
# NAME                       TYPE       CLUSTER-IP      PORT(S)
# ingress-nginx-controller   NodePort   10.104.12.201   80:30080/TCP,443:30443/TCP

kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       16m
```

---

## Install `etcd-client`

```sh
sudo apt-get install etcd-client -y

etcdctl version
# etcdctl version: 3.4.30
# API version: 3.4
```

---

## Review installed releases

```sh
helm list --all-namespaces
# NAME            NAMESPACE       REVISION  STATUS    CHART
# ingress-nginx   ingress-nginx   1         deployed  ingress-nginx-4.14.1
# metrics-server  kube-system     1         deployed  metrics-server-3.14.1
```
