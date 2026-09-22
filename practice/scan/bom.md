# CKS: bom

[Back](../../README.md)

- [CKS: bom](#cks-bom)
  - [Shortcut](#shortcut)
  - [bom](#bom)
  - [bom: scan image(killer B)](#bom-scan-imagekiller-b)

---

## Shortcut

- BOM and SBOM
  - You should know on how to create SBOM using `bom` tool based on requirements.
  - Example: Identify Image that has xyz 1.3.2 package and create SBOM for it.

| CMD                                                     | DESC                      |
| ------------------------------------------------------- | ------------------------- |
| `bom generate -i image_name --format json -o path_json` | Generate a SPDX-JSON SBOM |
| `bom document outline spdx_file`                        | visualize SBOMs           |

---

## bom

- task:
  - create sbom against image `nginx:1.19.1-alpine-perl`
  - ouput report `report.spdx`

```sh
# Scan container image using Trivy
trivy image nginx:1.19.1-alpine-perl

# Scan the image and create Software Bills of Material
bom generate --image nginx:1.19.1-alpine-perl --output report.spdx

# confirm
bom document outline report.spdx | head -n 30
```

---

## bom: scan image(killer B)

- task:
  - rceived Software Bill Of Materials (SBOM) requests and you have been selected to generate some documents and scans:
  - Using bom:
    - Generate a SPDX-JSON SBOM of image `registry.k8s.io/kube-apiserver:v1.31.0`
    - Store it at `/course/1/sbom1.json`
  - Using trivy:
    - Generate a CycloneDX SBOM of image `registry.k8s.io/kube-controller-manager:v1.31.0`
    - Store it at `/course/1/sbom2.json`
  - Using trivy:
    - Scan the existing SPDX-JSON SBOM at `/course/1/sbom_check.json` for known vulnerabilities.
    - Save the result in JSON format at `/course/1/sbom_check_result.json`

---

- solution:

```sh
# create sbom
bom generate -i registry.k8s.io/kube-apiserver:v1.31.0 --format json -o /course/1/sbom1.json
# confirm
cat /course/1/sbom1.json

# scan image
trivy image registry.k8s.io/kube-controller-manager:v1.31.0 --format cyclonedx -o /course/1/sbom2.json
# confirm
cat /course/1/sbom2.json

# scan sbom
trivy sbom /course/1/sbom_check.json --format json -o /course/1/sbom_check_result.json
# confirm
cat /course/1/sbom_check_result.json
```

---
