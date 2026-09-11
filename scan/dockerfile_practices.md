# CKS: secure Dockerfile

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## Dockerfile best practices

- **Use Updated Base Image**
  - The original Dockerfile uses ubuntu:18.04, which is outdated.
  - Switching to a more recent version like ubuntu:24.10 ensures better security, package support, and optimizations.

- **Prefer Minimal Image**
  - If the application does not require Ubuntu, a more minimal image like `alpine` can further reduce image size.

- **Reduce Number of Layers**
  - Instead of multiple RUN statement, **combine them into a single** `RUN` command

- **Avoid Running as Root**
  - The original `Dockerfile` uses `ROOT` user.
    - This gives full read, write, and execute permissions to everyone, which is a security risk.
  - Instead use other user with limited privilege.

---

## Lab: dockerfile

skip

ref: https://github.com/zealvora/certified-kubernetes-security-specialist/blob/main/domain-5-supply-chain-security/dockerfile-best-practice.md
