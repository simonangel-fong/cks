# CKS: Trivy

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)
  - [Trivy](#trivy)
    - [Common commands](#common-commands)
  - [Lab: install](#lab-install)
  - [Lab: Scan](#lab-scan)

---

## Container Security Scanning

- scan tools
  - DTR
  - Tenable
  - Trivy

- `Docker Trusted Registry (DTR)`
  - an enterprise-grade, **private image registry** designed for storing, managing, and **securing** `Docker images`

---

## Trivy

- `Trivy`
  - a free, open-source **security scanner** that **finds** software **flaws**, risky **misconfigurations**, and hidden **passwords** in code and containers.
    - an all-in-one **security checklist** for modern software development.

- Checks:
  - Container images
  - Code and repositories
  - Kubernetes
  - Infrastructure as Code (IaC)
  - Virtual machine images

- scan for:
  - Known vulnerabilities (CVEs)
  - Misconfigurations: Security settings left wide open by mistake
  - Exposed secrets
  - License issues

---

### Common commands

| Common                     | Description                                |
| -------------------------- | ------------------------------------------ |
| `trivy image <image_name>` | Scan a container image                     |
| `trivy config`             | Scan config files for misconfigurations    |
| `trivy fs`                 | Scan local filesystem                      |
| `trivy k8s`                | Scan kubernetes cluster                    |
| `trivy repo`               | Scan a repository                          |
| `trivy sbom`               | Scan SBOM for vulnerabilities and licenses |
| `trivy vm`                 | Scan a virtual machine image               |

---

## Lab: install

```sh
sudo apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

trivy version
# Version: 0.74.0
```

---

## Lab: Scan

- scan nginx image

```sh
# Vulnerabilities
trivy image nginx:latest
```

- Scan k8s

```sh
# scan our entire Kubernetes cluster for vulnerabilities and get a summary of the scan
trivy k8s --report=summary

# filter in-cluster security issues by severity of the vulnerabilities
trivy k8s --severity=CRITICAL --report=summary
```
