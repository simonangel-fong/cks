# Practices - Benchmark

[Back](../../README.md)

- [Practices - Benchmark](#practices---benchmark)
  - [CIS Benchmark fix controlplane](#cis-benchmark-fix-controlplane)
  - [kube-bench: cluster(killer A)](#kube-bench-clusterkiller-a)
  - [Task: kube-bench](#task-kube-bench)
  - [Task: kube-bench](#task-kube-bench-1)
  - [kube-bench - etcd data file](#kube-bench---etcd-data-file)

---

- CIS Benchmarks
  - It is important to know about configuring Kubernetes components (Control Plane + Worker Node) **based on various CIS Benchmark** related configuration.
  - Be very familiar with `kubeadm` structure and **troubleshooting** pointers.
  - take backup of the config file before modifying
  - e.g.,
    - Set AuthorizationMode for API Server to RBAC,WebHook
    - Disable Anonymous Authentication in Kubelet ( cat /var/lib/kubelet/config.yaml)
    - Disable --auto-tls in etcd

| Command                                                                               | description                   |
| ------------------------------------------------------------------------------------- | ----------------------------- |
| `kube-bench run --targets master`                                                     | benchmark master node         |
| `kube-bench run --targets etcd`                                                       | benchmark etcd                |
| `kube-bench run --targets master -c 1.2.15`                                           | benchmark against a document  |
| `kube-bench run -D cfg_dir`                                                           | specify kube-bench config dir |
| `kube-bench run --config config_file`                                                 | specify a config file         |
| `kube-bench run --benchmarkv cis-1.10`                                                | specify cis verion            |
| `kube-bench run --version string`                                                     | specify Kubernetes version    |
| `kube-bench --benchmark cis-1.10 --config-dir /opt/kube-bench/cfg run --targets node` |                               |

kube-bench --benchmark cis-1.10 --config-dir /opt/kube-bench/cfg run --targets master

- `--target`:
  - node: kubelet
  - etcd: etcd
  - master: controlplane and etcd

```sh
sudo groupadd --system etcd
sudo useradd -s /sbin/nologin --system -g etcd etcd
```

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

---

## Task: kube-bench

We have identified a few issues with our kubernetes setup and need your help in fixing them.

Fix the following issues on kubelet:

- Kubelet service file permission issues
- Kubelet config.yaml permission issues

Fix the following issues on etcd:

- Incorrect ownership of the etcd directory

Fix the following issues on the controlplane node:

- Incorrect value of the profiling argument for:
  - kube-controller-manager
  - kube-scheduler

Kube-bench is installed, and its config files are available under /opt/kube-bench. Use the cis-1.10 benchmark with the current Kubernetes version.

Note: Only fix issues that have the status FAIL, except issue number 1.2.5. Also, ignore the issues with policies.

---

- **Solution**

```sh
sudo kube-bench run --benchmark cis-1.10 \
  --config-dir /opt/kube-bench --config /opt/kube-bench/config.yaml \
  --targets master,node
```

Kubelet service file: Find the path reported by kube-bench; check it before editing.

```sh
sudo chmod 644 /path/to/kubelet.service
```

Kubelet configuration: CIS 1.10 requires permissions 600 or more restrictive

```sh
sudo chmod 600 /var/lib/kubelet/config.yaml
```

etcd data directory

```sh
sudo chown -R etcd:etcd /var/lib/etcd
```

Profiling

```sh
sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml
# - --profiling=false
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
```

---

## Task: kube-bench

Task
Run a CIS Benchmark scan using kube-bench and fix the etcd data directory permission issue.

Tasks:

- Run kube-bench to scan the master components
- Identify the etcd data directory permission violations

Requirements:

- Use kube-bench with appropriate targets to find the issue
- Restrict `etcd` directory permissions to the CIS recommended level
- Apply the fixes recursively to all files and subdirectories
- Verify that the fix resolves the violation

kube-bench is pre-installed. Focus on finding and fixing the etcd data directory permission issue specifically. Note: You may need to apply permissions recursively to ALL possible etcd directories and their contents.

---

```sh
kube-bench run --targets master

chmod -R 700 /var/lib/etcd
```

---

## kube-bench - etcd data file

Task
Please exit from `cluster2-controlplane` and ensure that you are in cluster1-controlplane for the subsequent question.

Run a CIS Benchmark scan using `kube-bench` and fix the `etcd` data directory permission issue.

Tasks:

Run kube-bench to scan the master components
Identify the etcd data directory permission violations
Requirements:

- Use kube-bench with appropriate targets to find the issue
- Restrict etcd directory permissions to the CIS recommended level
- Verify that the fix resolves the violation

kube-bench is pre-installed. Focus on finding and fixing the etcd data directory permission issue specifically.

---

- solution:

```sh
kube-bench run --targets master

chmod 700 /var/lib/etcd

sudo useradd -r -s /bin/false etcd 2>/dev/null
chown etcd:etcd /var/lib/etcd
```
