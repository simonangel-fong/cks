# Practices - falco

[Back](../README.md)

- [Practices - falco](#practices---falco)
  - [falco: rule pod sh???](#falco-rule-pod-sh)

---

- Falco
  - Be prepared to develop a `Falco rule` according to a given specification.
  - If you encounter issues with **Falco log generation**, verify that `syslog` is enabled with **debug priority**.
  - Alternatively, run `Falco` directly from the **command line**, bypassing `systemd`.

## falco: rule pod sh???

- context;
  - falco is installed and running
- task:
  - confirm falco is monitoring cluster
  - create a pod name `web-app` using `nginx:alpine`
  - `kubectl exec -it web-app -- sh`
  - check falco logs

---

- solution

```sh
# confirm falco is running
systemctl status falco
# ● falco-modern-bpf.service - Falco: Container Native Runtime Security with modern ebpf
#      Loaded: loaded (/usr/lib/systemd/system/falco-modern-bpf.service; enabled; preset: enabled)
#      Active: active (running) since Tue 2026-09-15 08:29:44 EDT; 51min ago
#        Docs: https://falco.org/docs/
#    Main PID: 8472 (falco)
#       Tasks: 18 (limit: 7689)
#      Memory: 72.0M (peak: 457.6M)
#         CPU: 38.029s
#      CGroup: /system.slice/falco-modern-bpf.service

sudo journalctl _COMM=falco -f


kubectl run web-app --image=nginx
# pod/web-app created

kubectl exec -it web-app -- sh

journalctl -fu falco

cat /var/log/syslog | grep falco
```
