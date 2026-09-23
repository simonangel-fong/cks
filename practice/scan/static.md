# Practices - Static analysis

[Back](../../README.md)

- [Practices - Static analysis](#practices---static-analysis)
  - [Shortcut](#shortcut)
    - [Static analysis: security context](#static-analysis-security-context)
    - [Dockerfile](#dockerfile)
  - [trivy: root file system](#trivy-root-file-system)
  - [trivy: scan image](#trivy-scan-image)
  - [trivy: scan cluster](#trivy-scan-cluster)
  - [Kubesec: Scan Kubernetes manifests](#kubesec-scan-kubernetes-manifests)
  - [Trivy: scan image(killer A)](#trivy-scan-imagekiller-a)

---

## Shortcut

- Static Analysis on Kubernetes Manifest
  - should be able to read a given Kubernetes manifest file and fix any security related issues.
    - know the best practices
    - focus on security context

| CMD                                                        | DESC           |
| ---------------------------------------------------------- | -------------- |
| `trivy image image_name --format cyclonedx -o output_file` | scan image     |
| `trivy sbom sbom_file --format json -o output_file`        | scan sbom file |

---

### Static analysis: security context

common Security context options

- **User and Group IDs**: Control which user/group the container runs as
- **Capabilities**: Add or drop Linux capabilities
- **Seccomp Profiles**: Set security computing profiles
- **SELinux Options**: Configure SELinux context
- **AppArmor**: Configure AppArmor profiles for additional access control
- **Windows Options**: Configure Windows-specific security settings

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  supplementalGroups: [4000]
  readOnlyRootFilesystem: true
  capabilities:
    add: ["NET_ADMIN", "SYS_TIME"]
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
```

- common risk:
  - `allowPrivilegeEscalation: true`
  - `capabilities.drop: []`
  - `privileged: true`

common manifest risk:

- `pod.command`: echo sensitive data; it will be kept in logs

  ```yaml
  command: ["/bin/sh"]
  args:
    - "-c"
    - "echo $SECRET_USERNAME && echo $SECRET_PASSWORD && docker-entrypoint.sh" # NOT GOOD
  ```

- use plaintext env

  ```yaml
  env:
    - name: Username
      value: Administrator
    - name: Password
      value: MyDiReCtP@sSw0rd
  ```

---

### Dockerfile

common issues:

- include sensitive files in layer, even if it get removed.

  ```txt
  COPY secret-token .
  RUN rm ./secret-token # delete secret token again
  ```

---

## trivy: root file system

- task:

performan a manual static analysis on files `/root/apps/app1-*`, concidering security by enforcing read-only root filesystem
Move the less secure file to `/root/insecure`

- setup env

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
  volumes:
    - name: sec-ctx-vol
      emptyDir: {}
  containers:
    - name: sec-ctx-demo
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
      volumeMounts:
        - name: sec-ctx-vol
          mountPath: /data/demo
      securityContext:
        allowPrivilegeEscalation: false
```

```sh
sudo mkdir -pv /root/apps
sudo tee /root/apps/app1-01.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
  volumes:
    - name: sec-ctx-vol
      emptyDir: {}
  containers:
    - name: sec-ctx-demo
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
      volumeMounts:
        - name: sec-ctx-vol
          mountPath: /data/demo
      securityContext:
        allowPrivilegeEscalation: false
EOF

trivy config /root/apps
```

---

- solution:
  - check each file for `readOnlyRootFilesystem`
  - move files without the key

```yaml
spec:
  securityContext:
    readOnlyRootFilesystem: true
```

---

## trivy: scan image

- question:
  - scan image
    - nginx:latest
    - alpine:latest
  - output the image name with less Critical vulnerabilities in the file: `/tmp/secure_image`

---

- solution

```sh
trivy image nginx:latest --severity CRITICAL
# Report Summary

# ┌────────────────────────────┬────────┬─────────────────┬─────────┐
# │           Target           │  Type  │ Vulnerabilities │ Secrets │
# ├────────────────────────────┼────────┼─────────────────┼─────────┤
# │ nginx:latest (debian 13.6) │ debian │        4        │    -    │
# └────────────────────────────┴────────┴─────────────────┴─────────┘

trivy image alpine:latest --severity CRITICAL
# Report Summary

# ┌───────────────────────────────┬────────┬─────────────────┬─────────┐
# │            Target             │  Type  │ Vulnerabilities │ Secrets │
# ├───────────────────────────────┼────────┼─────────────────┼─────────┤
# │ alpine:latest (alpine 3.24.1) │ alpine │        0        │    -    │
# └───────────────────────────────┴────────┴─────────────────┴─────────┘

touch /tmp/secure_image
echo "alpine:latest" > /tmp/secure_image

# confirm
cat /tmp/secure_image
# alpine:latest
```

---

## trivy: scan cluster

- task:
  - using `trivy` to scan images in ns `app` for oulnerabilities CVE and CVE
  - scale deployment to minimix the volunerabilities.

---

- set env

```sh
k create ns app
k create deploy web1 -n app --image=nginx:1.19.1-alpine-perl --replicas=2
k create deploy web2 -n app --image=nginx:1.20.2-alpine --replicas=2

```

- solution

```sh
k -n app get deploy

k -n app get pod -o yaml | grep image:
    # - image: nginx:1.19.1-alpine-perl
    #   image: docker.io/library/nginx:1.19.1-alpine-perl
    # - image: nginx:1.19.1-alpine-perl
    #   image: docker.io/library/nginx:1.19.1-alpine-perl
    # - image: nginx:1.20.2-alpine
    #   image: docker.io/library/nginx:1.20.2-alpine
    # - image: nginx:1.20.2-alpine
    #   image: docker.io/library/nginx:1.20.2-alpine

# scan each
trivy image nginx:1.19.1-alpine-perl | grep CVE-2021-28831
# │ busybox      │ CVE-2021-28831 │          │        │ 1.31.1-r9         │ 1.31.1-r10    │ busybox: invalid free or segmentation fault via malformed    │
# │ ssl_client   │ CVE-2021-28831 │ HIGH     │        │ 1.31.1-r9         │ 1.31.1-r10    │ busybox: invalid free or segmentation fault via malformed    │

trivy image nginx:1.19.1-alpine-perl | grep CVE-2016-9841
# none

trivy image nginx:1.20.2-alpine | grep CVE-2021-28831
# none

trivy image nginx:1.20.2-alpine | grep CVE-2016-9841
# none

# scale down risk
k -n app scale deploy web1 --replicas=0
# deployment.apps/web1 scaled

k -n app get deploy
# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# web1   0/0     0            0           6m50s
# web2   2/2     2            2           6m50s
```

---

## Kubesec: Scan Kubernetes manifests

- task:
  - scan `~/pod.yaml` using `kubesec`

- setup env:

```sh
cat <<EOF > ~/pod.yaml
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
```

```sh
# Scan manifest using binary
kubesec scan pod.yaml
```

---

## Trivy: scan image(killer A)

- task:
  - The Vulnerability Scanner `trivy` is installed on your main terminal. Use it to scan the following images for known CVEs:
    - nginx:1.30.2-alpine
    - registry.k8s.io/kube-apiserver:v1.35.1
    - registry.k8s.io/kube-controller-manager:v1.35.2
    - istio/pilot:1.28.0
  - Write all image names (including the tag, exactly as listed above) that are not affected by `CVE-2025-68121` or `CVE-2026-45447` into `/course/2/good-images`.

---

- solution

```sh
# scan image and output
trivy image nginx:1.30.2-alpine > /tmp/1
trivy image registry.k8s.io/kube-apiserver:v1.35.1 > /tmp/2
trivy image registry.k8s.io/kube-controller-manager:v1.35.2 > /tmp/3
trivy image istio/pilot:1.28.0 > /tmp/4

# inspect cve
grep -iE "CVE-2025-68121|CVE-2026-45447" /tmp/1
grep -iE "CVE-2025-68121|CVE-2026-45447" /tmp/2
grep -iE "CVE-2025-68121|CVE-2026-45447" /tmp/3
grep -iE "CVE-2025-68121|CVE-2026-45447" /tmp/4

# write the good image
echo <image> > /course/2/good-images

# confirm
cat /course/2/good-images

```
