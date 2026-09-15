# Practices - Benchmark

[Back](../README.md)

- [Practices - Benchmark](#practices---benchmark)
  - [CIS Benchmark fix controlplane](#cis-benchmark-fix-controlplane)
    - [Question](#question)
    - [Solution](#solution)

---

## CIS Benchmark fix controlplane

### Question

use kube-bench to ensure 1.2.15 has status PASS

---

### Solution

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
