# CKS - Master node: CNI and CoreDNS

[Back](../../index.md)

- [CKS - Master node: CNI and CoreDNS](#cks---master-node-cni-and-coredns)
  - [Install CNI - `Calico`](#install-cni---calico)
  - [Test control plane](#test-control-plane)
  - [Install CoreDNS](#install-coredns)
    - [Test DNS](#test-dns)

---

## Install CNI - `Calico`

```sh
# install CRDs
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/v1_crd_projectcalico_org.yaml

# install operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/tigera-operator.yaml

# confirm cluster Pod CIDR
kubectl cluster-info dump | grep -m 1 cluster-cidr
# "--cluster-cidr=10.244.0.0/16"

# download custom resources
curl -fL -o /tmp/custom-resources.yaml \
  https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/custom-resources.yaml

# update the default IP pool CIDR
sed -i 's|cidr: 192.168.0.0/16|cidr: 10.244.0.0/16|' /tmp/custom-resources.yaml

# create resources
kubectl create -f /tmp/custom-resources.yaml

# wait until all components are available
watch kubectl get tigerastatus

# confirm node status
kubectl get node
# NAME           STATUS   ROLES    AGE   VERSION
# controlplane   Ready    <none>   ...   v1.35.8
```

---

## Test control plane

```sh
kubectl get pods --all-namespaces
# NAMESPACE         NAME                                       READY   STATUS    RESTARTS   AGE
# calico-system     calico-apiserver-d6897b8df-dlc62           1/1     Running   0          79m
# calico-system     calico-apiserver-d6897b8df-p6rxz           1/1     Running   0          79m
# calico-system     calico-kube-controllers-86884dfdcf-8cxd2   1/1     Running   0          79m
# calico-system     calico-node-fz5wr                          1/1     Running   0          79m
# calico-system     calico-typha-86d46f7cdd-w9lth              1/1     Running   0          79m
# calico-system     csi-node-driver-fd725                      2/2     Running   0          79m
# calico-system     goldmane-5d7c56cd95-hll92                  1/1     Running   0          79m
# calico-system     whisker-5cc8cd46d5-x29pd                   2/2     Running   0          79m
# default           web                                        1/1     Running   0          47m
# kube-system       coredns-5c44b89985-vq98f                   1/1     Running   0          63m
# tigera-operator   tigera-operator-676bbdd645-7npnz           1/1     Running   0          85m
```

---

## Install CoreDNS

```sh
# download manifest
curl -fL -o /tmp/coredns.yaml \
  https://raw.githubusercontent.com/kubernetes/kubernetes/release-1.35/cluster/addons/dns/coredns/coredns.yaml.base

sed -i \
  -e 's/__DNS__DOMAIN__/cluster.local/g' \
  -e 's/__DNS__SERVER__/10.96.0.10/g' \
  -e 's/__DNS__MEMORY__LIMIT__/170Mi/g' \
  -e 's/__PILLAR__DNS__DOMAIN__/cluster.local/g' \
  -e 's/__PILLAR__DNS__SERVER__/10.96.0.10/g' \
  -e 's/__PILLAR__DNS__MEMORY__LIMIT__/170Mi/g' \
  -e 's/__PILLAR__CLUSTER__DNS__/10.96.0.10/g' \
  /tmp/coredns.yaml

sed -i 's|forward . /etc/resolv.conf|forward . 8.8.8.8 1.1.1.1|' /tmp/coredns.yaml

grep -n 'forward' /tmp/coredns.yaml
# 77:        forward . 8.8.8.8 1.1.1.1 {

kubectl apply -f /tmp/coredns.yaml
# serviceaccount/coredns created
# clusterrole.rbac.authorization.k8s.io/system:coredns created
# clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
# configmap/coredns created
# deployment.apps/coredns created
# service/kube-dns created

kubectl -n kube-system get pods -l k8s-app=kube-dns
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-...                1/1     Running   0          ...
```

### Test DNS

```sh
kubectl run dnsutils --image=registry.k8s.io/e2e-test-images/agnhost:2.39
# pod/dnsutils created

kubectl get pod dnsutils
# NAME       READY   STATUS    RESTARTS   AGE
# dnsutils   1/1     Running   0          ...

kubectl exec dnsutils -- nslookup kubernetes.default
# Name:      kubernetes.default.svc.cluster.local
# Address:   10.96.0.1

kubectl exec dnsutils -- nslookup kubernetes.default.svc.cluster.local
# Name:      kubernetes.default.svc.cluster.local
# Address:   10.96.0.1

kubectl delete pod dnsutils
# pod "dnsutils" deleted
```

---
