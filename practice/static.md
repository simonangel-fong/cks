# Practices - Static analysis

[Back](../README.md)

- [Practices - Static analysis](#practices---static-analysis)
  - [Static analysis: root file system](#static-analysis-root-file-system)
  - [Static analysis: security context](#static-analysis-security-context)
  - [trivy scan image](#trivy-scan-image)
  - [trivy scan cluster](#trivy-scan-cluster)
  - [Kubesec: Scan Kubernetes manifests](#kubesec-scan-kubernetes-manifests)

---

- Static Analysis on Kubernetes Manifest
  - should be able to read a given Kubernetes manifest file and fix any security related issues.
    - know the best practices
    - focus on security context

## Static analysis: root file system

- question

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
sudo nano /root/apps/app1-01.yaml

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

## Static analysis: security context

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

---

## trivy scan image

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

## trivy scan cluster

- task:
  - using `trivy` to scan images in ns `app` and `infra` for oulnerabilities CVE and CVE
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
