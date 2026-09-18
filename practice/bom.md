# CKS: bom

[Back](../README.md)

- [CKS: bom](#cks-bom)
  - [bom](#bom)

---

- BOM and SBOM
  - You should know on how to create SBOM using `bom` tool based on requirements.
  - Example: Identify Image that has xyz 1.3.2 package and create SBOM for it.

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
