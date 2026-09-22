# Practices - Benchmark

[Back](../../README.md)

- [Practices - Benchmark](#practices---benchmark)
  - [CIS Benchmark fix controlplane](#cis-benchmark-fix-controlplane)
  - [kube-bench: cluster(killer A)](#kube-bench-clusterkiller-a)

---

- CIS Benchmarks
  - It is important to know about configuring Kubernetes components (Control Plane + Worker Node) **based on various CIS Benchmark** related configuration.
  - Be very familiar with `kubeadm` structure and **troubleshooting** pointers.
  - take backup of the config file before modifying
  - e.g.,
    - Set AuthorizationMode for API Server to RBAC,WebHook
    - Disable Anonymous Authentication in Kubelet ( cat /var/lib/kubelet/config.yaml)
    - Disable --auto-tls in etcd

| Command                                     | description                   |
| ------------------------------------------- | ----------------------------- |
| `kube-bench run --targets master`           | benchmark master node         |
| `kube-bench run --targets etcd`             | benchmark etcd                |
| `kube-bench run --targets master -c 1.2.15` | benchmark against a document  |
| `kube-bench run --config-dir cfg_dir`       | specify kube-bench config dir |
| `kube-bench run --config config_file`       | specify a config file         |

## CIS Benchmark fix controlplane

- task
  - use kube-bench to ensure 1.2.15 has status PASS

---

- Solution

```sh
# run check for all
sudo kube-bench run --targets master | grep -A2 "1.2.15"
# [FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.2.16 Ensure that the --audit-log-path argument is set (Automated)
# [FAIL] 1.2.17 Ensure that the --audit-log-maxage argument is set to 30 or as appropriate (Automated)
# --
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false

# run check for one
sudo kube-bench run --targets master -c "1.2.15"
# [INFO] 1 Control Plane Security Configuration
# [INFO] 1.2 API Server
# [FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)

# == Remediations master ==
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false


# == Summary master ==
# 0 checks PASS
# 1 checks FAIL
# 0 checks WARN
# 0 checks INFO

# == Summary total ==
# 0 checks PASS
# 1 checks FAIL
# 0 checks WARN
# 0 checks INFO

# backup to /tmp; do not backup at the same path;
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
#     - --profiling=false

# wait apiserver restart
# confirm
sudo kube-bench run --targets master -c 1.2.15
# [INFO] 1 Control Plane Security Configuration
# [INFO] 1.2 API Server
# [PASS] 1.2.15 Ensure that the --profiling argument is set to false (Automated)

# == Summary master ==
# 1 checks PASS
# 0 checks FAIL
# 0 checks WARN
# 0 checks INFO

# == Summary total ==
# 1 checks PASS
# 0 checks FAIL
# 0 checks WARN
# 0 checks INFO
```

- debug

```sh
# if apiserver cannot load new manifest, force to recreate container
sudo crictl rm -f $(sudo crictl ps -q --name kube-apiserver)

sudo journalctl -u kubelet --since '10 min ago' | tail -50
```

---

## kube-bench: cluster(killer A)

- task:
- You're asked to evaluate specific settings of the cluster against the CIS Benchmark recommendations. Use the kube-bench tool which is already installed on the nodes.
  - Connect to the worker node from controlplane `ssh node01`
  - On the controlplane node ensure (correct if necessary) that the CIS recommendations are set for:
    - The `--profiling` argument of the `kube-controller-manager`
    - The ownership of directory `/var/lib/etcd`
  - On the worker node ensure (correct if necessary) that the CIS recommendations are set for:
    - The permissions of the kubelet configuration `/var/lib/kubelet/config.yaml`
    - The `--client-ca-file` argument of the `kubelet`

---

- solution

```sh
sudo -i
# controlplane
kube-bench run --targets master > cis0

vi cis0
# find
# --profiling=false, kube-controller-manager
# /var/lib/etcd

# fix
vi /etc/kubernetes/manifests/kube-controller-manager.yaml
# - --profiling=false
# fix
chown etcd:etcd /var/lib/etcd

# confirm
kube-bench run --targets master > cis1
vi cis1
# previous warning no found


ssh node01
sudo -i

kube-bench run --targets node > cis0
vi cis0
# find
# /var/lib/kubelet/config.yaml
# --client-ca-file

# fix
chmod 600 /var/lib/kubelet/config.yaml
vi /var/lib/kubelet/config.yaml
# authentication:
#   x509:
#     clientCAFile: /etc/kubernetes/pki/ca.crt

systemctl restart kubelet
systemctl status kubelet

kube-bench run --targets node > cis1
vi cis1
# no found preivous warning
```
