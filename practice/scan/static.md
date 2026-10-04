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
  - [Task: bom](#task-bom)
  - [Task: static analysis](#task-static-analysis)
  - [Task: kubesec](#task-kubesec)
  - [Task: immutable pod](#task-immutable-pod)
  - [Task: Servcie](#task-servcie)
  - [kubelinter](#kubelinter)
  - [OPA](#opa)
  - [pod - resource](#pod---resource)
  - [pod - volume](#pod---volume)

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

---

## Task: bom

A deployment named fruits in the namespace salad has three containers:

apple
banana, and
kiwi
One of these containers has the package curl installed. Identify which container has that package from the running containers, and create an SBOM SPDX for the container's image.

Use the tarball archive of that particular image stored under /root/ImageTarballs directory for generating the SPDX JSON. The archives have names matching their images.

Save the output in ~/bugged-fruit.spdx. Save the container name in ~/bugged-container.txt.

Note: bom as well as all its required dependencies have already been installed.

---

- **Solution**

```sh
kubectl -n salad exec POD -c apple -- which curl
kubectl -n salad exec POD -c banana -- which curl
kubectl -n salad exec POD -c kiwi -- which curl

echo CONTAINER_NAME > ~/bugged-container.txt

bom generate \
  --image-archive /root/ImageTarballs/CONTAINER_NAME-image.tar \
  --format json \
  --output ~/bugged-fruit.spdx
```

---

## Task: static analysis

The Release Engineering Team has shared some YAML manifests and Dockerfiles with you for review. These files are located under `/opt/course/`.

As a container security expert, your task is to perform a manual static analysis and identify possible security issues related to unwanted credential exposure. Note that running processes as root is not a concern in this task.

Record the filenames containing issues in `/opt/course/security-issues.txt`.

Note: Assume that all referenced files, folders, secrets, and volume mounts are present in the Dockerfiles and YAML manifests. You can ignore any syntax or logic errors.

---

- **Solution**

- Dockerfile: layer
- k8s manifests plaintext

---

## Task: kubesec

Task
A pod definition file has been created at /root/CKS/simple-pod.yaml . Use the kubesec tool to generate a report for this pod definition file and fix the major issues so that the subsequent scan passes.

Once done, generate the report again and save it to the file /root/CKS/kubesec-report.txt

---

- **Solution**

Solution
Remove the `SYS_ADMIN` capability from the container for the simple-webapp-1 pod in the POD definition file and re-run the scan.

```sh
kubesec scan /root/CKS/simple-pod.yaml > /root/CKS/kubesec-report.txt
```

The fixed report should PASS with a message like this:

```json
[
  {
    "object": "Pod/simple-webapp-1.default",
    "valid": true,
    "fileName": "simple-pod.yaml",
    "message": "Passed with a score of 0 points",
    "score": 0,
  },
  ...
]
```

---

## Task: immutable pod

Task
Delete all pods from the alpha namespace that are not immutable.

Note: A pod is considered non-immutable if it uses elevated privileges or can store state inside the container.

---

- Solution

Solution
Pod `solaris` is immutable as it have `readOnlyRootFilesystem: true` so it should not be deleted.

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsUser: 1000
```

Pod `sonata` is running with `privileged: true`. break the concept of immutability and should be deleted.

```yaml
securityContext:
  privileged: true
  readOnlyRootFilesystem: false
```

Pod `triton` doesn't define `readOnlyRootFilesystem: true`. break the concept of immutability and should be deleted.

```yaml
# no securityContext
```

---

## Task: Servcie

Task
You have an existing Kubernetes setup with the following services running:

Namespace:
`system-hardening`

Pods:
`nginx-internal` (Accessible internally)
`nginx-external` (Exposed externally via NodePort
service)

Services:
`nginx-internal-service` (Exposed as ClusterIP - internal-only)
`nginx-external-service` (Exposed as NodePort - accessible externally)

Objective:
Your task is to disable or unexpose ports to minimize external access to unnecessary services.

---

- Solution:
- check labels for the pod
  - add labels
- replace NodePort by ClusterIP
  - http + https

---

## kubelinter

Task
A vulnerable deployment has been identified in the `security-scanning` namespace. Your task is to utilize the pre-configured `KubeLinter` configuration located at `/root/kube-linter-config.yaml` to identify and rectify all security issues in this deployment.

Tasks:

Scan the vulnerable deployment using the provided `KubeLinter` configuration.
Identify all security violations present in the deployment.
Address and resolve the security issues identified in the deployment.
Verify that the revised deployment successfully passes all security checks.
The vulnerable deployment can be found at `/tmp/.init/manifests/vulnerable-deployment.yaml`, and `KubeLinter` is pre-installed with the configuration file already set up.

---

- **Solution**
  Step 1: Scan the Vulnerable Deployment

```sh
kubelinter lint /tmp/.init/manifests/vulnerable-deployment.yaml --config /root/kube-linter-config.yaml
```

Step 2: Identify Security Issues
The scan will reveal the following security issues:

- Privileged container
- No read-only root filesystem
- Running as root user
- Using latest image tag
- Missing resource limits

Step 3: Create a Fixed Deployment

```yaml
# /tmp/.init/manifests/vulnerable-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
  namespace: security-scanning
spec:
  replicas: 2
  selector:
    matchLabels:
      app: insecure-app
  template:
    metadata:
      labels:
        app: insecure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - insecure-app
                    topologyKey: kubernetes.io/hostname
      containers:
        - name: app
          image: nginx:1.25-alpine
          securityContext:
            privileged: false
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop:
                - ALL
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
```

Step 5: Verify Security Fixes

```sh
kubelinter lint /tmp/.init/manifests/vulnerable-deployment.yaml --config /root/kube-linter-config.yaml
```

---

## OPA

`OPA Gatekeeper` is installed to enforce that all pods in the `gatekeeper-demo` namespace have resource limits defined. A ConstraintTemplate named `k8srequiredresources` is already created that validates CPU and memory limits. Create a Constraint that enforces this policy.

Tasks:

- Ensure `Gatekeeper` pods are ready in the `gatekeeper-system` namespace
- Verify the existing `ConstraintTemplate` k8srequiredresources is ready
- Create a `Constraint` named must-have-resources that targets the gatekeeper-demo namespace
- Test the policy by attempting to create a pod without resource limits

Constraint Requirements:

- Name: must-have-resources
- Kind: K8sRequiredResources
- Target namespace: gatekeeper-demo
- Parameters: limits: true

---

- solution:

- Step 1: Wait for Gatekeeper to be Ready

```sh
kubectl get pods -n gatekeeper-system
```

- Step 2: Verify ConstraintTemplate is Ready

```sh
# Check that the ConstraintTemplate exists and is ready
kubectl get constrainttemplate k8srequiredresources
```

- Step 3: Create Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: must-have-resources
spec:
  match:
    namespaces: ["gatekeeper-demo"]
  parameters:
    limits: true
```

- Step 4: Test the Policy

```yaml
# This should fail - no resource limits
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: gatekeeper-demo
spec:
  containers:
    - name: nginx
      image: nginx:alpine
```

```yaml
# This should succeed - with resource limits
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-with-limits
  namespace: gatekeeper-demo
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
```

- Step 5: Verify Constraint Status

```sh
kubectl get k8srequiredresources must-have-resources -o yaml
```

---

## pod - resource

Task
Configure resource limits for a pod to ensure predictable performance and prevent resource starvation. Create a pod named `limited-pod` in the `resource-demo` namespace with the following specifications:

Pod Requirements:

- Pod name: limited-pod
- Namespace: resource-demo
- Label: app: limited-pod
- Container name: app
- Image: nginx:alpine

Resource Configuration:

- CPU request: 100m
- CPU limit: 100m
- Memory request: 64Mi
- Memory limit: 64Mi

Tasks:

Create the pod with both resource requests and limits defined
Ensure the pod achieves "Guaranteed" QoS class by setting equal requests and limits
Verify the pod is running successfully

---

- solution

Resource Limits and QoS Classes Solution

- Step 1: Create the pod with equal requests and limits for Guaranteed QoS

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limited-pod
  namespace: resource-demo
  labels:
    app: limited-pod
spec:
  containers:
    - name: app
      image: nginx:alpine
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
```

- Step 2: Verify the pod configuration

```sh
# Check the pod is running
kubectl get pod limited-pod -n resource-demo

# Check resource requests and limits
kubectl get pod limited-pod -n resource-demo -o jsonpath='{.spec.containers[0].resources}'

# Verify QoS class (should be Guaranteed)
kubectl get pod limited-pod -n resource-demo -o jsonpath='{.status.qosClass}'
```

- Step 3: Detailed verification

```sh
# Get detailed pod information
kubectl describe pod limited-pod -n resource-demo
```

Understanding QoS Classes:

- Guaranteed: All containers have memory/CPU limits EQUAL to requests
- Burstable: At least one container has memory/CPU request < limit
- BestEffort: No resource requests or limits specified
  Key Points:
  For Guaranteed QoS, BOTH CPU and memory must have equal requests and limits
  Lower memory (64Mi) ensures the pod can schedule on resource-constrained nodes
  Guaranteed pods are last to be killed during resource contention

---

## pod - volume

Task
Create a pod named `volume-app` in the `volume-security` namespace that uses a hostPath volume with proper security measures to restrict volume access and prevent potential host system compromise.

Security Requirements:

- Mount the hostPath volume as read-only to prevent modifications to the host filesystem
- Use a specific directory `/var/log/app` on the host
- Set the volume mount to read-only mode
- Ensure the pod runs as non-root user (UID 1000)

Pod Specifications:

- Pod name: volume-app
- Namespace: volume-security
- Label: app: volume-app
- Container name: logger
- Image: busybox
- Command: ['sh', '-c', 'tail -f /dev/null']
- Volume mount path: /app/logs

This configuration allows log reading without granting write access to the host system.

HostPath volumes can be security risks if not properly configured. Always use read-only mounts when possible.

---

- solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-app
  namespace: volume-security
  labels:
    app: volume-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: logger
      image: busybox
      command: ["sh", "-c", "tail -f /dev/null"]
      volumeMounts:
        - name: app-logs
          mountPath: /app/logs
          readOnly: true
  volumes:
    - name: app-logs
      hostPath:
        path: /var/log/app
        type: Directory
```
