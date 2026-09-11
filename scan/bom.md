# CKS: Bill of Materials

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## Bill of Materials

- `Bill of Materials (BOM)`
  - lists all the components, quantity, materials required to manufacture an item.

- `Software Bill of Materials (SBOM)`
  - listing all **components, libraries, and dependencies** that make up a software application.

- tools of sbom
  - Trivy, Syft, Bom

- 2 most widely used SBOM Formats
  - SPDX (Software Package Data Exchange)
  - CycloneDX

| Features                        | SPDX                                                          | CycloneDX                                       |
| ------------------------------- | ------------------------------------------------------------- | ----------------------------------------------- |
| Developed By                    | Linux Foundation                                              | OWASP                                           |
| Focus Area                      | License compliance, intellectual property, security           | Security, software supply chain risk management |
| Primary Use Case                | Used widely in open source compliance and legal audits        | Used mainly for security, vulnerability         |
| management, and risk assessment |
| Complexity                      | More complex, detailed metadata about licenses and compliance | Simplified, security-focused, lightweight       |

---

## `bom` commands

| Command          | Desccription                                               |
| ---------------- | ---------------------------------------------------------- |
| `bom completion` | Generate the autocompletion script for the specified shell |
| `bom document`   | bom document → Work with SPDX documents                    |
| `bom generate`   | bom generate → Create SPDX SBOMs                           |
| `bom version`    | Prints the version of the bom tool                         |

---

## Lab: `bom`

### Install

- ref: https://kubernetes-sigs.github.io/bom/quick-start/

```sh
# latest version
curl -L \
  https://github.com/kubernetes-sigs/bom/releases/download/v0.7.1/bom-amd64-linux \
  -o /tmp/bom

sudo install -m 0755 /tmp/bom /usr/local/bin/bom

bom version
# ______  _____ ___  ___
# | ___ \|  _  ||  \/  |
# | |_/ /| | | || .  . |
# | ___ \| | | || |\/| |
# | |_/ /\ \_/ /| |  | |
# \____/  \___/ \_|  |_/
# bom: A tool for working with SPDX manifests

# GitVersion:    v0.7.1
# GitCommit:     1ab6284
# GitTreeState:  clean
# BuildDate:     2025-09-26T06:24:16Z
# GoVersion:     go1.25.1
# Compiler:      gc
# Platform:      linux/amd64
```

### create bom

```sh
bom generate --output=debian.spdx --image debian@sha256:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491
# INFO bom v0.7.1: Generating SPDX Bill of Materials
# INFO Processing image reference: debian@sha256:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491
# INFO Reference debian@sha256:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491 points to a single image
# INFO Generating single image package for debian@sha256:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491
# INFO Package describes image index.docker.io/library/debian:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491
# INFO Image manifest lists 1 layers
# INFO etc/os-release is a symlink, following to usr/lib/os-release
# INFO Scan of container layers found debian base image
# INFO Layer 0 has a newer version of dpkg database
# INFO Scan of container image returned 87 OS packages in layer #0
# WARN Document has no name defined, automatically set to SBOM-SPDX-16edb1f9-6513-447e-a2ee-74effac2f352
# INFO Package SPDXRef-Package-sha256-0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491 has 1 relationships defined
# INFO Package SPDXRef-Package-index.docker.io-library-debian-0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491-sha256-b37cbf60a964400132f658413bf66b67e5e67da35b9c080be137ff3c37cc7f65 has 87 relationships defined

head debian.spdx
# SPDXVersion: SPDX-2.3
# DataLicense: CC0-1.0
# SPDXID: SPDXRef-DOCUMENT
# DocumentName: SBOM-SPDX-16edb1f9-6513-447e-a2ee-74effac2f352
# DocumentNamespace: https://spdx.org/spdxdocs/k8s-releng-bom-fc16e32d-bd55-457e-8cc3-1f28ce9fd239
# Creator: Organization: Kubernetes Release Engineering
# Creator: Tool: bom-v0.7.1
# LicenseListVersion: 3.27
# Created: 2026-09-11T20:47:59Z

# Draw structure of a SPDX document",
bom document outline debian.spdx | head -20
#                _
#  ___ _ __   __| |_  __
# / __| '_ \ / _` \ \/ /
# \__ \ |_) | (_| |>  <
# |___/ .__/ \__,_/_/\_\
#     |_|

#  📂 SPDX Document SBOM-SPDX-16edb1f9-6513-447e-a2ee-74effac2f352
#   │
#   │ 📦 DESCRIBES 1 Packages
#   │
#   ├ sha256:0aac521df91463e54189d82fe820b6d36b4a0992751c8339fbdd42e2bc1aa491
#   │  │ 🔗 1 Relationships
#   │  └ CONTAINS PACKAGE sha256:b37cbf60a964400132f658413bf66b67e5e67da35b9c080be137ff3c37cc7f6
#   │  │  │ 🔗 87 Relationships
#   │  │  ├ CONTAINS PACKAGE apt@2.5.4
#   │  │  ├ CONTAINS PACKAGE base-files@12.3
#   │  │  ├ CONTAINS PACKAGE base-passwd@3.6.1
#   │  │  ├ CONTAINS PACKAGE bash@5.2.15-2
#   │  │  ├ CONTAINS PACKAGE bsdutils@1:2.38.1-4
```

---

## Lab: bom with trivy

```sh
# ####################
# scan image and output spdx
# ####################
trivy image \
  --format spdx-json \
  --output nginx.spdx.json \
  nginx:latest

# 2026-09-11T16:34:11-04:00       INFO    "--format spdx-json" disables security scanning. Specify "--scanners vuln" explicitly if you want to include vulnerabilities in the "spdx-json" report.
# 2026-09-11T16:34:18-04:00       INFO    Detected OS     family="debian" version="13.6"
# 2026-09-11T16:34:18-04:00       INFO    Number of language-specific files       num=0

ls nginx.spdx.json
# nginx.spdx.json

head nginx.spdx.json
# {
#   "spdxVersion": "SPDX-2.3",
#   "dataLicense": "CC0-1.0",
#   "SPDXID": "SPDXRef-DOCUMENT",
#   "name": "nginx:latest",
#   "documentNamespace": "http://trivy.dev/container_image/nginx:latest-be78a96b-d12b-47ac-8b47-3647d75035f1",
#   "creationInfo": {
#     "creators": [
#       "Organization: aquasecurity",
#       "Tool: trivy-0.74.0"

# ####################
# scan image and output cyclonedx
# ####################
trivy image \
  --format cyclonedx \
  --output nginx.cyclone.json \
  nginx:latest

# 2026-09-11T16:36:13-04:00       INFO    "--format cyclonedx" disables security scanning. Specify "--scanners vuln" explicitly if you want to include vulnerabilities in the "cyclonedx" report.
# 2026-09-11T16:36:14-04:00       INFO    Detected OS     family="debian" version="13.6"
# 2026-09-11T16:36:14-04:00       INFO    Number of language-specific files       num=0

head nginx.cyclone.json
# {
#   "$schema": "http://cyclonedx.org/schema/bom-1.7.schema.json",
#   "bomFormat": "CycloneDX",
#   "specVersion": "1.7",
#   "serialNumber": "urn:uuid:ef68341a-adb3-433c-8b4a-e3b3ac60e625",
#   "version": 1,
#   "metadata": {
#     "timestamp": "2026-09-11T20:36:14+00:00",
#     "tools": {
#       "components": [

# Scan SBOM for vulnerabilities and licenses
trivy sbom nginx.spdx.json | head -20
# 2026-09-11T16:38:05-04:00       INFO    [vuln] Vulnerability scanning is enabled
# 2026-09-11T16:38:05-04:00       INFO    Detected SBOM format    format="spdx-json"
# 2026-09-11T16:38:05-04:00       INFO    Detected OS     family="debian" version="13.6"
# 2026-09-11T16:38:05-04:00       INFO    [debian] Detecting vulnerabilities...   os_version="13" pkg_num=151
# 2026-09-11T16:38:05-04:00       INFO    Number of language-specific files       num=0
# 2026-09-11T16:38:05-04:00       WARN    Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.74/guide/scanner/vulnerability#severity-selection for details.

# Report Summary

# ┌───────────────────────────────┬────────┬─────────────────┐
# │            Target             │  Type  │ Vulnerabilities │
# ├───────────────────────────────┼────────┼─────────────────┤
# │ nginx.spdx.json (debian 13.6) │ debian │       321       │
# └───────────────────────────────┴────────┴─────────────────┘
# Legend:
# - '-': Not scanned
# - '0': Clean (no security findings detected)


# nginx.spdx.json (debian 13.6)
# =============================
# Total: 321 (UNKNOWN: 28, LOW: 116, MEDIUM: 105, HIGH: 68, CRITICAL: 4)

# ┌─────────────────────────┬─────────────────────┬──────────┬──────────────┬──────────────────────────────────────┬──────────────────┬──────────────────────────────────────────────────────────────┐
# │         Library         │    Vulnerability    │ Severity │    Status    │          Installed Version           │  Fixed Version   │                            Title                             │
# ├─────────────────────────┼─────────────────────┼──────────┼──────────────┼──────────────────────────────────────┼──────────────────┼──────────────────────────────────────────────────────────────┤


trivy sbom nginx.cyclone.json | head -25
# 2026-09-11T16:38:49-04:00       INFO    [vuln] Vulnerability scanning is enabled
# 2026-09-11T16:38:49-04:00       INFO    Detected SBOM format    format="cyclonedx-json"
# 2026-09-11T16:38:49-04:00       INFO    Detected OS     family="debian" version="13.6"
# 2026-09-11T16:38:49-04:00       INFO    [debian] Detecting vulnerabilities...   os_version="13" pkg_num=151
# 2026-09-11T16:38:49-04:00       INFO    Number of language-specific files       num=0
# 2026-09-11T16:38:49-04:00       WARN    Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.74/guide/scanner/vulnerability#severity-selection for details.

# Report Summary

# ┌──────────────────────────────────┬────────┬─────────────────┐
# │              Target              │  Type  │ Vulnerabilities │
# ├──────────────────────────────────┼────────┼─────────────────┤
# │ nginx.cyclone.json (debian 13.6) │ debian │       321       │
# └──────────────────────────────────┴────────┴─────────────────┘
# Legend:
# - '-': Not scanned
# - '0': Clean (no security findings detected)


# nginx.cyclone.json (debian 13.6)
# ================================
# Total: 321 (UNKNOWN: 28, LOW: 116, MEDIUM: 105, HIGH: 68, CRITICAL: 4)

# ┌─────────────────────────┬─────────────────────┬──────────┬──────────────┬──────────────────────────────────────┬──────────────────┬──────────────────────────────────────────────────────────────┐
# │         Library         │    Vulnerability    │ Severity │    Status    │          Installed Version           │  Fixed Version   │                            Title                             │
# ├─────────────────────────┼─────────────────────┼──────────┼──────────────┼──────────────────────────────────────┼──────────────────┼──────────────────────────────────────────────────────────────┤
# │ apt                     │ CVE-2011-3374       │ LOW      │ affected     │ 3.0.3                                │                  │ It was found that apt-key in apt, all versions, do not       │
# │                         │                     │          │              │                                      │                  │ correctly...                                                 │
# │                         │                     │          │              │                                      │                  │ https://avd.aquasec.com/nvd/cve-2011-3374                    │
# ├─────────────────────────┼─────────────────────┤          │              ├──────────────────────────────────────┼──────────────────┼──────────────────────────────────────────────────────────────┤
# │ bash                    │ TEMP-0841856-B18BAF │          │              │ 5.2.37-2+b9                          │                  │ [Privilege escalation possible to other user than root]      │

```
