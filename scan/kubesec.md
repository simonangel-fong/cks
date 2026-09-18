# CKS: kubesec

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## kubesec

## Lab: install

```sh
wget https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz
tar -xzvf kubesec_linux_amd64.tar.gz

sudo mv kubesec /usr/bin/

kubesec version
# version 2.14.2
# git commit bb804de5ed6f311a7d281c3d119fe85e77e75a13
# build date 2024-11-22T16:34:22Z
```

---

## Lab: scan

```sh
cat <<EOF > kubesec-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubesec-demo
spec:
  containers:
  - name: kubesec-demo
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      readOnlyRootFilesystem: true
EOF

kubesec scan kubesec-test.yaml
# [
#   {
#     "object": "Pod/kubesec-demo.default",
#     "valid": true,
#     "fileName": "kubesec-test.yaml",
#     "message": "Passed with a score of 1 points",
#     "score": 1,
#     "scoring": {
#       "passed": [
#         {
#           "id": "ReadOnlyRootFilesystem",
#           "selector": "containers[] .securityContext .readOnlyRootFilesystem == true",
#           "reason": "An immutable root filesystem can prevent malicious binaries being added to PATH and increase attack cost",
#           "points": 1
#         }
#       ],
#       "advise": [
#         {
#           "id": "ApparmorAny",
#           "selector": ".metadata .annotations .\"container.apparmor.security.beta.kubernetes.io/nginx\"",
#           "reason": "Well defined AppArmor policies may provide greater protection from unknown threats. WARNING: NOT PRODUCTION READY",
#           "points": 3
#         },
#         {
#           "id": "ServiceAccountName",
#           "selector": ".spec .serviceAccountName",
#           "reason": "Service accounts restrict Kubernetes API access and should be configured with least privilege",
#           "points": 3
#         },
#         {
#           "id": "SeccompAny",
#           "selector": ".metadata .annotations .\"container.seccomp.security.alpha.kubernetes.io/pod\"",
#           "reason": "Seccomp profiles set minimum privilege and secure against unknown threats",
#           "points": 1
#         },
#         {
#           "id": "AutomountServiceAccountToken",
#           "selector": ".spec .automountServiceAccountToken == false",
#           "reason": "Disabling the automounting of Service Account Token reduces the attack surface of the API server",
#           "points": 1
#         },
#         {
#           "id": "RunAsGroup",
#           "selector": ".spec, .spec.containers[] | .securityContext .runAsGroup -gt 10000",
#           "reason": "Run as a high-UID group to avoid conflicts with the host's groups",
#           "points": 1
#         },
#         {
#           "id": "RunAsNonRoot",
#           "selector": ".spec, .spec.containers[] | .securityContext .runAsNonRoot == true",
#           "reason": "Force the running image to run as a non-root user to ensure least privilege",
#           "points": 1
#         },
#         {
#           "id": "RunAsUser",
#           "selector": ".spec, .spec.containers[] | .securityContext .runAsUser -gt 10000",
#           "reason": "Run as a high-UID user to avoid conflicts with the host's users",
#           "points": 1
#         },
#         {
#           "id": "LimitsCPU",
#           "selector": "containers[] .resources .limits .cpu",
#           "reason": "Enforcing CPU limits prevents DOS via resource exhaustion",
#           "points": 1
#         },
#         {
#           "id": "LimitsMemory",
#           "selector": "containers[] .resources .limits .memory",
#           "reason": "Enforcing memory limits prevents DOS via resource exhaustion",
#           "points": 1
#         },
#         {
#           "id": "RequestsCPU",
#           "selector": "containers[] .resources .requests .cpu",
#           "reason": "Enforcing CPU requests aids a fair balancing of resources across the cluster",
#           "points": 1
#         },
#         {
#           "id": "RequestsMemory",
#           "selector": "containers[] .resources .requests .memory",
#           "reason": "Enforcing memory requests aids a fair balancing of resources across the cluster",
#           "points": 1
#         },
#         {
#           "id": "CapDropAny",
#           "selector": "containers[] .securityContext .capabilities .drop",
#           "reason": "Reducing kernel capabilities available to a container limits its attack surface",
#           "points": 1
#         },
#         {
#           "id": "CapDropAll",
#           "selector": "containers[] .securityContext .capabilities .drop | index(\"ALL\")",
#           "reason": "Drop all capabilities and add only those required to reduce syscall attack surface",
#           "points": 1
#         }
#       ]
#     }
#   }
# ]

# specify rule
kubesec print-rules
```
