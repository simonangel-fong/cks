# CKS - Master node: Kubernetes Scheduler

[Back](../../index.md)

- [CKS - Master node: Kubernetes Scheduler](#cks---master-node-kubernetes-scheduler)
  - [Kubernetes Scheduler - Overview](#kubernetes-scheduler---overview)
    - [Required files](#required-files)
    - [Identity](#identity)
  - [PKI](#pki)
  - [Configure `kube-scheduler.conf`](#configure-kube-schedulerconf)
  - [Install `kube-scheduler`](#install-kube-scheduler)
  - [Verify control plane](#verify-control-plane)

---

## Kubernetes Scheduler - Overview

### Required files

Files required by the `kube-scheduler` systemd unit:

| File                                         | Type          | Purpose                                  |
| -------------------------------------------- | ------------- | ---------------------------------------- |
| `/etc/kubernetes/config/kube-scheduler.yaml` | Configuration | Configures the scheduler                 |
| `/etc/kubernetes/kube-scheduler.conf`        | Kubeconfig    | Connects the scheduler to the API server |

### Identity

| Certificate          | CN                      | O                      | Purpose                         |
| -------------------- | ----------------------- | ---------------------- | ------------------------------- |
| `kube-scheduler.crt` | `system:kube-scheduler` | `system:kube-scheduler` | Authenticates to the API server |

---

## PKI

```sh
cd ~/pki

# ##############################
# Create client cert: scheduler
# ##############################
# create client certificates: kube-scheduler
gen_client kube-scheduler "/CN=system:kube-scheduler/O=system:kube-scheduler"
# Certificate request self-signature ok
# subject=CN = system:kube-scheduler, O = system:kube-scheduler
# removed 'kube-scheduler.csr'

ls -l kube-scheduler.*
# -rw-rw-r-- 1 ubuntuadmin ubuntuadmin ... kube-scheduler.crt
# -rw------- 1 ubuntuadmin ubuntuadmin ... kube-scheduler.key

# confirm
openssl x509 -in "kube-scheduler.crt" -noout -subject
# subject=CN = system:kube-scheduler, O = system:kube-scheduler


# ##############################
# Install
# ##############################
sudo install -v -m 644 kube-scheduler.crt /etc/kubernetes/pki/kube-scheduler.crt
# 'kube-scheduler.crt' -> '/etc/kubernetes/pki/kube-scheduler.crt'
sudo install -v -m 600 kube-scheduler.key /etc/kubernetes/pki/kube-scheduler.key
# 'kube-scheduler.key' -> '/etc/kubernetes/pki/kube-scheduler.key'
ls -l /etc/kubernetes/pki/kube-scheduler.crt /etc/kubernetes/pki/kube-scheduler.key
# -rw-r--r-- 1 root root ... /etc/kubernetes/pki/kube-scheduler.crt
# -rw------- 1 root root ... /etc/kubernetes/pki/kube-scheduler.key
```

---

## Configure `kube-scheduler.conf`

The `kube-scheduler.conf` defines _where_ the API server is, _who_ the client is, and _which CA_ to trust.

```sh
cd ~/pki

# ##############################
# Configure kubeconfig: kube-scheduler
# ##############################
# set cluster
kubectl config set-cluster kubernetes \
  --server=https://127.0.0.1:6443 \
  --embed-certs=true \
  --certificate-authority=ca.crt \
  --kubeconfig=kube-scheduler.conf

# Cluster "kubernetes" set.

# set user
kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.crt \
  --client-key=kube-scheduler.key \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.conf

# User "system:kube-scheduler" set.

# set context
kubectl config set-context default  \
    --cluster=kubernetes \
    --user=system:kube-scheduler  \
    --kubeconfig=kube-scheduler.conf

# Context "default" created.

kubectl config use-context default --kubeconfig=kube-scheduler.conf
# Switched to context "default".


# ##############################
# Install kubeconfig: kube-scheduler
# ##############################
sudo install -v -m 600 kube-scheduler.conf \
  /etc/kubernetes/kube-scheduler.conf

# 'kube-scheduler.conf' -> '/etc/kubernetes/kube-scheduler.conf'
```

---

## Install `kube-scheduler`

```sh
export K8S_VERSION=v1.35.8

# ##############################
# Download kube-scheduler
# ##############################
cd /tmp
curl -fL -o kube-scheduler "https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kube-scheduler"
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100 46.1M  100 46.1M    0     0  11.4M      0  0:00:04  0:00:04 --:--:-- 11.4M

sudo install -v -m 755 kube-scheduler /usr/local/bin/
# 'kube-scheduler' -> '/usr/local/bin/kube-scheduler'

kube-scheduler --version
# Kubernetes v1.35.8

# ##############################
# Configure kube-scheduler
# ##############################
sudo mkdir -pv /etc/kubernetes/config
# mkdir: created directory '/etc/kubernetes/config'
cat <<'EOF' | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/kube-scheduler.conf
leaderElection:
  leaderElect: true
EOF

# ##############################
# Configure systemd unit: kube-scheduler
# ##############################
cat <<'EOF' | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://kubernetes.io/docs/concepts/overview/components/
After=kube-apiserver.service

[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --config=/etc/kubernetes/config/kube-scheduler.yaml \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload config
sudo systemctl daemon-reload
# start and enable
sudo systemctl enable --now kube-scheduler
# Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service

# confirm
sudo systemctl status kube-scheduler --no-pager --full
# ● kube-scheduler.service - Kubernetes Scheduler
#      Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; preset: enabled)
#      Active: active (running) since Thu 2026-09-03 15:58:38 EDT; 10s ago
#        Docs: https://kubernetes.io/docs/concepts/overview/components/
#    Main PID: 4807 (kube-scheduler)
#       Tasks: 8 (limit: 3179)
#      Memory: 12.7M (peak: 13.0M)
#         CPU: 81ms
#      CGroup: /system.slice/kube-scheduler.service
#              └─4807 /usr/local/bin/kube-scheduler --config=/etc/kubernetes/config/kube-scheduler.yaml --v=2

# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482172    4807 reflector.go:446] "Caches populated" type="*v1.StatefulSet" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482184    4807 reflector.go:446] "Caches populated" type="*v1.PersistentVolume" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482225    4807 reflector.go:446] "Caches populated" type="*v1.CSIDriver" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482246    4807 reflector.go:446] "Caches populated" type="*v1.PersistentVolumeClaim" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482258    4807 reflector.go:446] "Caches populated" type="*v1.Service" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482326    4807 reflector.go:446] "Caches populated" type="*v1.PodDisruptionBudget" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482332    4807 reflector.go:446] "Caches populated" type="*v1.StorageClass" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.482356    4807 reflector.go:446] "Caches populated" type="*v1.ReplicaSet" reflector="k8s.io/client-go/informers/factory.go:161"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.570596    4807 leaderelection.go:258] "Attempting to acquire leader lease..." lock="kube-system/kube-scheduler"
# Sep 03 15:58:38 controlplane kube-scheduler[4807]: I0903 15:58:38.575329    4807 leaderelection.go:272] "Successfully acquired lease" lock="kube-system/kube-scheduler"
```

---

## Verify control plane

```sh
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler --no-pager

# component health
kubectl get --raw='/readyz?verbose'
# [+]ping ok
# [+]log ok
# [+]etcd ok
# [+]etcd-readiness ok
# [+]informer-sync ok
# [+]poststarthook/start-apiserver-admission-initializer ok
# [+]poststarthook/generic-apiserver-start-informers ok
# [+]poststarthook/priority-and-fairness-config-consumer ok
# [+]poststarthook/priority-and-fairness-filter ok
# [+]poststarthook/storage-object-count-tracker-hook ok
# [+]poststarthook/start-apiextensions-informers ok
# [+]poststarthook/start-apiextensions-controllers ok
# [+]poststarthook/crd-informer-synced ok
# [+]poststarthook/start-system-namespaces-controller ok
# [+]poststarthook/start-cluster-authentication-info-controller ok
# [+]poststarthook/start-kube-apiserver-identity-lease-controller ok
# [+]poststarthook/start-kube-apiserver-identity-lease-garbage-collector ok
# [+]poststarthook/start-legacy-token-tracking-controller ok
# [+]poststarthook/start-service-ip-repair-controllers ok
# [+]poststarthook/rbac/bootstrap-roles ok
# [+]poststarthook/scheduling/bootstrap-system-priority-classes ok
# [+]poststarthook/priority-and-fairness-config-producer ok
# [+]poststarthook/bootstrap-controller ok
# [+]poststarthook/start-kubernetes-service-cidr-controller ok
# [+]poststarthook/aggregator-reload-proxy-client-cert ok
# [+]poststarthook/start-kube-aggregator-informers ok
# [+]poststarthook/apiservice-status-local-available-controller ok
# [+]poststarthook/apiservice-status-remote-available-controller ok
# [+]poststarthook/apiservice-registration-controller ok
# [+]poststarthook/apiservice-discovery-controller ok
# [+]poststarthook/kube-apiserver-autoregistration ok
# [+]autoregister-completion ok
# [+]poststarthook/apiservice-openapi-controller ok
# [+]poststarthook/apiservice-openapiv3-controller ok
# [+]shutdown ok
# readyz check passed

kubectl cluster-info
# Kubernetes control plane is running at https://127.0.0.1:6443

# get lease
kubectl -n kube-system get lease
# NAME                                   HOLDER                                                                      AGE
# apiserver-ivtlveyukuyrha5ia44unn7io4   apiserver-ivtlveyukuyrha5ia44unn7io4_e706adfd-ddc8-4433-a3d0-9ef1fd695bae   138m
# kube-controller-manager                controlplane_688a4b95-4e59-497b-b85c-d59c15330e5f                           81s
# kube-scheduler                         controlplane_5a199782-59c5-4004-8ad4-f0e7e4a324bb                           48m
```

---
