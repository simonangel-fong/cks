# CKS: kube-bench

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## kube-bench

- `kube-bench`
  - a Go application that **checks** whether Kubernetes is deployed securely by running the checks documented in the `Center for Internet Security (CIS)` Kubernetes Benchmark.

- output results
  - 🟢 PASS:
    - The configuration meets the required security standard.
  - 🔴 FAIL:
    - The setting is vulnerable or improperly configured.
    - It usually accompanies a remediation step telling you exactly how to fix the issue.
  - 🟡 WARN / INFO:
    - The check requires manual intervention or a deeper look based on your unique architecture.

---

## Lab: install

- ref: https://aquasecurity.github.io/kube-bench/v0.6.6/installation/

```sh
# Download
curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.16.0/kube-bench_0.16.0_linux_amd64.deb -o /tmp/kube-bench.deb

# Install
sudo apt install /tmp/kube-bench.deb

# Verify
kube-bench version
# 0.16.0
s
sudo kube-bench
# ...
# == Summary policies ==
# 0 checks PASS
# 0 checks FAIL
# 24 checks WARN
# 0 checks INFO

# == Summary total ==
# 69 checks PASS
# 12 checks FAIL
# 41 checks WARN
# 0 checks INFO

```