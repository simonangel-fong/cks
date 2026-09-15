# Practices - Secure the node

[Back](../README.md)

- [Practices - Secure the node](#practices---secure-the-node)
  - [close an unknow port](#close-an-unknow-port)
  - [`NodeRestriction`](#noderestriction)

---

## close an unknow port

- question
  - unwanted process running and listening on port `2379`
  - kill the process and delete the binary

- solution

```sh
# get all port
sudo ss -tlpn | grep 2379
# LISTEN 0      4096        127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=2309,fd=6))
# LISTEN 0      4096   192.168.10.150:2379       0.0.0.0:*    users:(("etcd",pid=2309,fd=7))

sudo ls -l /proc/2309/exe
# lrwxrwxrwx 1 root root 0 Sep 14 08:09 /proc/2309/exe -> /usr/local/bin/etcd

sudo lsof -i :2379
# COMMAND     PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
# etcd       2309 root    6u  IPv4   25542      0t0  TCP localhost:2379 (LISTEN)
# etcd       2309 root    7u  IPv4   25544      0t0  TCP controlplane:2379 (LISTEN)
# etcd       2309 root    9u  IPv4  418593      0t0  TCP localhost:2379->localhost:41892 (ESTABLISHED)
# etcd       2309 root   13u  IPv4  419507      0t0  TCP localhost:2379->localhost:41918 (ESTABLISHED)

# force to kill
kill -9 2309

# remove
rm /usr/local/bin/etcd
```

---

## `NodeRestriction`

- task:
  - enable `NodeRestriction` admission controller
  - verify by adding the label `node-restrition.kubernetes.io/two=123` from `node01` to `node01`

---

- solution
  - ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction

```sh
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --enable-admission-plugins=NodeRestriction,NamespaceLifecycle

# ####################
# label from node01
# ####################
# label current node as control-plane
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 node-role.kubernetes.io/control-plane="" --overwrite
# Error from server (Forbidden): nodes "worker-node-01" is forbidden: User "system:node:node01" cannot get resource "nodes" in API group "" at the cluster scope: node 'node01' cannot read 'worker-node-01', only its own Node object

# label current node as restiction
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 node-restriction.kubernetes.io/="" --overwrite
# Error from server (Forbidden): nodes "node01" is forbidden: is not allowed to modify labels: node-restriction.kubernetes.io/

# label controlplane node
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node controlplane new-label="123" --overwrite
# Error from server (Forbidden): nodes "controlplane" is forbidden: User "system:node:node01" cannot get resource "nodes" in API group "" at the cluster scope: node 'node01' cannot read 'controlplane', only its own Node object

# label current node a new label
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 new-label="123" --overwrite
# node/node01 labeled

# ####################
# label from controlplane
# ####################
# label node01
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf label node node01 node-role.kubernetes.io/control-plane="" --overwrite
# node/node01 labeled

# label controlplane node
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node controlplane new-label="123" --overwrite
# node/controlplane labeled
```