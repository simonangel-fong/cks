# CKS: Static analysis

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## Static analysis

- `Static analysis` / `static code analysis`
  - a method of **debugging and evaluating** computer software by examining source code, bytecode, or binaries without running the program.

- `Checkov`
  - an open-source **static analysis and policy-as-code tool** that scans `infrastructure as code (IaC)` files, container **images**, and open-source **packages** for security vulnerabilities, compliance violations, and misconfigurations before deployment.

---

## Common COmmands

| Command                                           | Description                      |
| ------------------------------------------------- | -------------------------------- |
| `checkov -d . --framework dockerfile`             | Scan dockerfile                  |
| `checkov -f Dockerfile`                           | Scan dockerfile                  |
| `checkov -f Dockerfile --skip-check CKV_DOCKER_2` | Scan dockerfile and skip a check |

---

## Lab: static analysis k8s manifests

```sh
# install checkov
sudo apt update && sudo apt install python3-pip python3.12-venv -y

python3 -m venv ~/cks/.venv
source ~/cks/.venv/bin/activate
pip install checkov

# confirm
checkov --version
# 3.3.17

# create manifest
tee ~/cks/static_analysis.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged
spec:
  containers:
  - image: nginx
    name: demo-pod
    # securityContext:
    #   privileged: true
EOF

# scan
checkov -f ~/cks/static_analysis.yaml
# [ kubernetes framework ]: 100%|████████████████████|[1/1], Current File Scanned=static_analysis.y
# [ secrets framework ]: 100%|████████████████████|[1/1], Current File Scanned=/home/ubuntuadmin/ck

#        _               _
#    ___| |__   ___  ___| | _______   __
#   / __| '_ \ / _ \/ __| |/ / _ \ \ / /
#  | (__| | | |  __/ (__|   < (_) \ V /
#   \___|_| |_|\___|\___|_|\_\___/ \_/

# By Prisma Cloud | version: 3.3.17

# kubernetes scan results:

# Passed checks: 69, Failed checks: 20, Skipped checks: 0
```
