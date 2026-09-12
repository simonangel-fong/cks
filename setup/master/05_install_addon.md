# CKS setup: master install addon

## Install `helm`

```sh
sudo apt-get install curl gpg apt-transport-https -y

# update key
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm

helm version
# version.BuildInfo{Version:"v4.3.0", GitCommit:"bec5b06ed841fe5269972d864d5177944fd5970f", GitTreeState:"clean", GoVersion:"go1.27.1", KubeClientVersion:"v1.37"}
```

---

## Install CNI

```sh
# ##############################
# Install CNI
# ##############################
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/operator-crds.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml

# get cluster ip cidr
kubectl cluster-info dump | grep -m 1 cluster-cidr
#  "--cluster-cidr=10.244.0.0/16",

# Download the custom resources necessary to configure Calico.
curl -fL -o /tmp/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  1046  100  1046    0     0   5340      0 --:--:-- --:--:-- --:--:--  5364

sed 's/192.168.0.0/10.244.0.0/' /tmp/custom-resources.yaml

vi /tmp/custom-resources.yaml
# find:
# spec:
#   calicoNetwork:
#     ipPools:
#       - name: default-ipv4-ippool
#         cidr: 192.168.0.0/16
# replace:
# spec:
#   calicoNetwork:
#     ipPools:
#       - name: default-ipv4-ippool
#         cidr: 10.244.0.0/16

# create resources
kubectl create -f /tmp/custom-resources.yaml
# installation.operator.tigera.io/default created
# apiserver.operator.tigera.io/default created
# goldmane.operator.tigera.io/default created
# whisker.operator.tigera.io/default created

watch -n 1 kubectl get tigerastatus
# NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
# apiserver   True        False         False      44s
# calico      True        False         False      39s
# goldmane    True        False         False      19s
# ippools     True        False         False      109s
# whisker     True        False         False      39s

k get node
# NAME           STATUS   ROLES           AGE   VERSION
# controlplane   Ready    control-plane   50m   v1.35.8
```

## Install metrics server

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# confirm install
kubectl get deployment metrics-server -n kube-system
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# metrics-server   0/1     1            0           6m8s

# update yaml metrics server
kubectl edit deployment metrics-server -n kube-system
# find:
# spec:
#   template:
#     spec:
#       containers:
#       - args:
# add:
# spec:
#   template:
#     spec:
#       containers:
#       - args:
#         - --kubelet-insecure-tls
#         - --kubelet-preferred-address-types=InternalIP

# restart metric server
kubectl rollout restart deployment metrics-server -n kube-system
# deployment.apps/metrics-server restarted

kubectl get deployment metrics-server -n kube-system

kubectl top node
```

## Install `etcd-client`

```sh
# install
sudo apt install etcd-client

# confirm
etcdctl version
# etcdctl version: 3.4.30
# API version: 3.4
```

---

---

## Install `nginx ingress controller`

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml

kubectl get deploy --namespace=ingress-nginx
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# ingress-nginx-controller   1/1     1            1           16m

kubectl get ingressclass
```
