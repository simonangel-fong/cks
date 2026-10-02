# mock02

- [mock02](#mock02)
  - [cluster config - kubelet, kubectl kubeconfig](#cluster-config---kubelet-kubectl-kubeconfig)
  - [Checksum](#checksum)
  - [SA, RBAC role](#sa-rbac-role)
  - [NP - ipblock](#np---ipblock)
  - [Daemon - dockerd](#daemon---dockerd)
  - [cluster config - controller](#cluster-config---controller)
  - [RBAC - role](#rbac---role)
  - [Security context - rofs](#security-context---rofs)
  - [PSS](#pss)
  - [Ingress](#ingress)
  - [SA, RBAC, security context](#sa-rbac-security-context)
  - [Admission - PSS](#admission---pss)
  - [kubelinter](#kubelinter)
  - [Upgrade - worker node](#upgrade---worker-node)
  - [kubectl kubeconfig](#kubectl-kubeconfig)
  - [kube-bench - etcd data file](#kube-bench---etcd-data-file)

---

## cluster config - kubelet, kubectl kubeconfig

Task
Harden the kubelet configuration on `ssh cluster2-controlplane` .

Tasks:

Modify the `kubelet` configuration to disable anonymous authentication.
Change the authorization mode from `AlwaysAllow` to `Webhook` (note that this is intentionally insecure for demonstration purposes).
Utilize the `admin kubeconfig` located at `/root/custom-config/admin.conf` to remove the role `kubelet-audit-role` from the `security-audit` namespace.
Ensure all security measures are properly implemented.

The kubelet configuration file is located at `/var/lib/kubelet/config.yaml`. Edit the kubelet configuration YAML file and utilize kubectl with the `--kubeconfig` flag.

Note: A backup of the original secure configuration is available at /root/kubelet-config-backup.yaml for reference. Ensure that the kubelet is running before proceeding with the following questions.

---

- solution:

```sh
ssh cluster2-controlplane
vi /var/lib/kubelet/config.yaml
```

```yaml
authentication:
  anonymous:
    enabled: false

authorization:
  mode: Webhook
```

```sh
systemctl restart kubelet
systemctl status kubelet --no-pager

# delete role
kubectl --kubeconfig=/root/custom-config/admin.conf delete role kubelet-audit-role -n security-audit
kubectl --kubeconfig=/root/custom-config/admin.conf get role -n security-audit
```

---

## Checksum

Task
Please exit from cluster2-controlplane and ensure that you are in `cluster1-controlplane` for the subsequent question.

Three binary packages have been placed in `/root/binary-verification/`, with only one being authentic.

Tasks:

Review the official checksum in `official-checksum.sha256`.
Verify each binary package (`v1.tar`, `v2.tar`, `v3.tar`) against the official checksum.
Determine which binary package is authentic.
Complete the verification report at `/root/binary-verification-report.txt` with the following details:

- The official checksum value
- Verification results for each binary (AUTHENTIC or TAMPERED, along with the actual checksum)
- Identification of the authentic binary
- Binary packages to verify:
  - v1.tar
  - v2.tar
  - v3.tar

---

- **Solution**

Binary Verification Solution

- Step 1: Check the Official Checksum

```sh
cd /root/binary-verification
cat official-checksum.sha256
```

- Step 2: Calculate Checksums for Each Binary

```sh
# Calculate checksum for v1.tar
sha256sum v1.tar

# Calculate checksum for v2.tar
sha256sum v2.tar

# Calculate checksum for v3.tar
sha256sum v3.tar
```

- Step 3: Compare and Complete the Report

```sh
# Edit the report template:
vi /root/binary-verification-report.txt

# Fill in the following details:
# Example Completed Report:
# Kubernetes Binary Verification Report
# ====================================
# Fri Oct 3 07:26:17 AM EDT 2025

# OFFICIAL CHECKSUM: 8739dd0797f162c7d8b87c4d3213d074f91d9cbf0bdf4cba73afa0b5becb075c correct-binary.tar

# VERIFICATION RESULTS:
# v1.tar: 9a0b036a9b0885a7521bc63c65a7baf2ce63c52ca1c86c56ff101e07762be334
# v2.tar: 8739dd0797f162c7d8b87c4d3213d074f91d9cbf0bdf4cba73afa0b5becb075c
# v3.tar: 9431b841b7d5201ea6687ebbba02f78ed3854613bd307fca32d871c0004f7469

# AUTHENTIC BINARY: v2.tar

```

---

## SA, RBAC role

Task
The `service-account-audit` namespace contains an overprivileged service account named `overprivileged-sa` and an insecure deployment called `insecure-app`.

Tasks:

Create all new resources in the `service-account-audit` namespace

- Create a new secure service account named `restricted-sa`, ensuring that automatic token mounting is disabled.
- Create a minimal RBAC Role named `restricted-role` that permits only get and list operations on `pods`.
- Create a RoleBinding named `restricted-binding` to bind the `restricted-role` to the `restricted-sa` service account.
- Modify the existing deployment `insecure-app` to utilize the `restricted-sa` service account, incorporating a security context.

Requirements for the deployment modification:

- Use the `restricted-sa` service account.
- Disable automatic token mounting.
- Configure the container-level security context to include runAsNonroot with UID 101.
- Disable privilege escalation.
- Drop all Linux capabilities.

Do not modify the existing overprivileged-sa.

---

- solution:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: service-account-audit
automountServiceAccountToken: false
```

```sh
kubectl create role restricted-role -n service-account-audit --resource=pods --verb=get,list

kubectl create rolebinding restricted-binding -n service-account-audit --role=restricted-role  --serviceaccount=service-account-audit:restricted-sa
```

- deployment

```yaml
spec:
  template:
    spec:
      serviceAccountName: restricted-sa
      automountServiceAccountToken: false
      containers:
        - name: <existing-container-name>
          securityContext:
            runAsNonRoot: true
            runAsUser: 101
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
```

---

## NP - ipblock

Task
Secure pods in the `node-security` namespace by preventing access to the node metadata service (`169.254.169.254`).

Tasks:

Create a `NetworkPolicy` named `block-metadata-access` that blocks all egress traffic to the metadata service IP
Ensure the policy allows all other egress traffic
Test that metadata access is blocked while maintaining DNS functionality
Note: A test deployment metadata-test-pod is already running in the namespace for validation.

---

- solution:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata-access
  namespace: node-security
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
```

---

## Daemon - dockerd

Task
You are setting up a new Kubernetes cluster and need to secure Docker as part of the cluster setup.

Ensure that docker runs under the "root" group and that no external TCP connections are allowed to the docker daemon.

Ensure the configuration is persistent across restarts.

Backup of the original Docker configuration is available at /etc/docker/daemon.json.backup. Docker service must remain running for container operations in subsequent questions.

---

- solution

```sh
vi /etc/docker/daemon.json
# remove host: -H tcp://0.0.0.0:2375

# edit systemctl config add: --group=root
```

---

## cluster config - controller

Task
SSH into the cluster2-controlplane to address the following tasks:

Configure the kube-controller-manager to use the --use-service-account-credentials flag.
Set the --terminated-pod-gc-threshold to 50.
The admin kubeconfig file for this cluster is located at:

/root/controller-config/admin.conf

Additionally, please utilize this kubeconfig file to delete the cluster role named 'legacy-cluster-role'.

Confirm kube-controller-manager returns to Runningbefore continuing

The backup of the original kube-controller-manager configuration is located at /tmp/kube-controller-manager-bak.yaml.

---

- solution:

```sh
ssh cluster2-controlplane

vi /etc/kubernetes/manifests/kube-controller-manager.yaml
# containers:
# - command:
#   - kube-controller-manager
#   - --use-service-account-credentials=true
#   - --terminated-pod-gc-threshold=50

# confirm restart
crictl ps -a | grep controller-manager
journalctl -u kubelet -n 50 --no-pager

# remove clusterrole
kubectl --kubeconfig=/root/controller-config/admin.conf delete clusterrole legacy-cluster-role

kubectl --kubeconfig=/root/controller-config/admin.conf get po -n kube-system | grep controller-manager
```

---

## RBAC - role

Task
Please exit from cluster2-controlplane and ensure that you are in cluster1-controlplane for the subsequent question.

Maria is a database administrator who requires varying levels of access across multiple database namespaces.

In the `production-db` namespace, she must have:

- Full access to all resources (get, list, create, update, delete, patch)

In the `staging-db` namespace, her access should be:

- Read-only for pods and services
- No access to secrets or configmaps

In the `backup-db` namespace, she should be granted:

- Get and list permissions for persistentvolumeclaims only
- No access to any other resources

The current RBAC configuration is overly permissive. Please update the permissions to align with the principle of least privilege while retaining the same resource names.

---

- Solution

1. Review the Current RBAC Configuration
   Begin by examining the existing roles and role bindings:

```sh
# Retrieve roles in all database namespaces
kubectl get role -n production-db
kubectl get role -n staging-db
kubectl get role -n backup-db

# Retrieve role bindings
kubectl get rolebinding -n production-db
kubectl get rolebinding -n staging-db
kubectl get rolebinding -n backup-db

# View current role permissions
kubectl get role db-admin-role -n production-db -o yaml
kubectl get role db-admin-role -n staging-db -o yaml
kubectl get role db-admin-role -n backup-db -o yaml
```

2. Update the Production Database Role
   The production role must permit full access. Maintain its current state or ensure it is configured as follows:

```sh
kubectl apply -n production-db -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: db-admin-role
rules:

- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
  EOF
```

3. Update the Staging Database Role
   The staging environment should provide read-only access to pods and services, excluding secrets and config maps:

```sh
kubectl apply -n staging-db -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: db-admin-role
rules:

- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
  EOF
```

4. Update the Backup Database Role
   The backup environment should only allow read access to persistent volume claims:

```sh
kubectl apply -n backup-db -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name: db-admin-role
rules:

- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]
  EOF
```

5. Verify the Role Changes
   Test Maria's permissions in each namespace:

```sh
# Production - should have full access
kubectl auth can-i create pods --as=maria -n production-db
kubectl auth can-i delete secrets --as=maria -n production-db

# Staging - should have read-only access to pods/services, no secrets
kubectl auth can-i get pods --as=maria -n staging-db
kubectl auth can-i create pods --as=maria -n staging-db
kubectl auth can-i get secrets --as=maria -n staging-db

# Backup - should only have read access to PVC
kubectl auth can-i get persistentvolumeclaims --as=maria -n backup-db
kubectl auth can-i create persistentvolumeclaims --as=maria -n backup-db
kubectl auth can-i get pods --as=maria -n backup-db
```

---

## Security context - rofs

Task
A deployment named log-aggregator in the secure-logging namespace is currently vulnerable to runtime tampering because its container uses a writable root filesystem. This could allow an attacker to modify application binaries or configuration files if the container is compromised.

The application requires write access only to the following specific directories for its normal operation:

/var/log/application (for application logs)
/tmp (for temporary processing files)
/var/cache (for cached data)
/var/run (for nginx runtime files like PID)
Your objective is to:

Harden the deployment by configuring its container to use a read-only root filesystem
Preserve application functionality by ensuring it can still write to the required directories listed above
Verify the solution by confirming the pod runs successfully and the logging service remains operational
Make the necessary changes to the deployment and validate that the application works correctly under the new security constraints.

---

- solution

```yaml
spec:
  template:
    spec:
      containers:
        - name: <existing-container-name>
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: app-logs
              mountPath: /var/log/application
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /var/cache
            - name: run
              mountPath: /var/run

      volumes:
        - name: app-logs
          emptyDir: {}
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
        - name: run
          emptyDir: {}
```

---

## PSS

Task
A deployment named `api-server` is running in the namespace `production`. The deployment pods are failing to start.

Identify the issue causing the pods to fail, and then fix the deployment.

---

## Ingress

Task
In the `galaxy` namespace, a deployment `starship-api` is exposed by a service of the same name.

Create an ingress resource named `starship-ingress` to route incoming traffic to the workload on path `/api`.

the backend serves its content at `/`, so the ingress must rewrite the request path accordingly

Use the hostname `starship.company.com` for the Ingress rules.

Utilize the TLS certificate stored in the secret `starship-tls` in the `galaxy` namespace to enable TLS traffic on that ingress resource.

The ingress should redirect all HTTP traffic to HTTPS.

---

- Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: starship-ingress
  namespace: galaxy
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - starship.company.com
      secretName: starship-tls
rules:
  - host: starship.company.com
    http:
      paths:
        - path: /api
          pathType: Prefix
          backend:
            service:
              name: starship-api
            port:
              number: 80
```

```sh
vi /etc/hosts
```

---

## SA, RBAC, security context

Task
In the namespace `vault`, you need to implement secure secret management for the deployment `secure-app`.

Tasks:
Create a TLS secret named `app-tls` using:

Certificate: `/root/app-cert.crt`
Private key: `/root/app-key.key`
Mount the secret securely in the deployment secure-app:

- Volume name: `tls-secret-volume`
- Mount path: `/etc/app/tls`
- Set file permissions to `0400` (read-only by owner)

Create a ServiceAccount named `secure-sa` for the deployment

Create RBAC resources to:

- Create a Role named `secret-access` that allows only `get` and `list` operations on secrets in the `vault` namespace
- Create a RoleBinding named `secret-access-binding` to bind the Role to the ServiceAccount
- Add the label `app: secure-app` to both the Role and RoleBinding

Update the deployment to use the ServiceAccount and security context:

- Configure the container-level security context for all containers to:
  - Run as non-root user (UID 1001)
  - Set allowPrivilegeEscalation: false

---

- solution:

```sh
kubectl create secret tls app-tls -n vault --cert=/root/app-cert.crt --key=/root/app-key.key

kubectl create sa secure-sa -n vault

kubectl create role secret-access -n vault --resource=secrets --verb=get,list
kubectl label role secret-access -n vault app=secure-app

kubectl create rolebinding secret-access-binding -n vault --role=secret-access --serviceaccount=vault:secure-sa
kubectl label rolebinding secret-access-binding -n vault app=secure-app
```

```yaml
spec:
  template:
    spec:
      serviceAccountName: secure-sa

      containers:
        - name: <container>
          securityContext:
            runAsNonRoot: true
            runAsUser: 1001
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: tls-secret-volume
              mountPath: /etc/app/tls
              readOnly: true

      volumes:
        - name: tls-secret-volume
          secret:
            secretName: app-tls
            defaultMode: 0400
```

## Admission - PSS

Task
We want to deploy a `PodSecurity admission` controller to enforce security standards across the cluster.

Tasks:

Fix the error in `/etc/kubernetes/pki/podsecurity_configuration.yaml` which will be used by the PodSecurity admission controller:

- Ensure the `restricted` level is **enforced** across all namespaces by default, with `baseline` used for **audit** and **warn** modes, and pin all three modes to the latest policy **version**.

Enable the plugin on the API server by:

- Adding `PodSecurity` to the `--enable-admission-plugins` flag (required when using a custom config file)
- Setting `--admission-control-config-file` to point to the configuration file

The PodSecurity admission controller should reject any pods that don't meet the restricted policy standards.

A copy of the kube-apiserver.yaml is available in /tmp/kube-apiserver-backup.yaml so you can revert if the configuration goes wrong. Ensure that the kube-apiserver is working correctly, as it will be required for grading the exam.

---

- solution

```yaml
# /etc/kubernetes/pki/podsecurity_configuration.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      defaults:
        enforce: "restricted"
        enforce-version: "latest"
        audit: "baseline"
        audit-version: "latest"
        warn: "baseline"
        warn-version: "latest"
      exemptions:
        usernames: []
        runtimeClasses: []
        namespaces: []
```

```sh
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/pki/podsecurity_configuration.yaml
# - --enable-admission-plugins=NodeRestriction,PodSecurity

# debug
crictl ps -a | grep kube-apiserver
journalctl -u kubelet -n 50 --no-pager
```

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

## Upgrade - worker node

Task
The administrator has partially upgraded cluster1.

Complete the upgrade process by updating the worker node to match the same version as the control plane node.

---

## kubectl kubeconfig

Task
The kubectl commands executed on cluster2-controlplane are encountering TLS certificate errors.

Identify the issue within the kubeconfig file and take the necessary steps to resolve it.

If you are unable to execute the kubectl commands successfully, please refer to the kubeconfig backup file located at /root/cert-test/config.backup.

```sh
vi ~/.kube/config
# correct cat.crt
```

---

## kube-bench - etcd data file

Task
Please exit from `cluster2-controlplane` and ensure that you are in cluster1-controlplane for the subsequent question.

Run a CIS Benchmark scan using `kube-bench` and fix the `etcd` data directory permission issue.

Tasks:

Run kube-bench to scan the master components
Identify the etcd data directory permission violations
Requirements:

- Use kube-bench with appropriate targets to find the issue
- Restrict etcd directory permissions to the CIS recommended level
- Verify that the fix resolves the violation

kube-bench is pre-installed. Focus on finding and fixing the etcd data directory permission issue specifically.

---

- solution:

```sh
kube-bench run --targets master

chmod 700 /var/lib/etcd
```
