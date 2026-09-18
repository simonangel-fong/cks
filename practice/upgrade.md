# Practice: Upgrade Cluster

[back](../README.md)

- [Practice: Upgrade Cluster](#practice-upgrade-cluster)
  - [Upgrade controlplane](#upgrade-controlplane)

---

- Kubernetes Cluster Upgrade
  - Learn to upgrade both control plane and worker nodes using kubeadm

- common troubleshooting
  - kubectl down:
    - check kubelet, systemctl status
    - check kubelet log, journalctl -u kubelet
    - check log files apiserver, tail /var/log/pods/apiserver
    - confirm with document, e.g., flag; space issue: `flag = value`
    - backup config file
    - fix config file
    - confirm, kubectl get

## Upgrade controlplane
