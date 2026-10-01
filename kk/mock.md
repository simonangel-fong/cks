# kk mock

[Back](../README.md)

- [kk mock](#kk-mock)
  - [Task: RBAC - clusterrole](#task-rbac---clusterrole)
  - [Task: falco - find pod](#task-falco---find-pod)
  - [Task: Network policy - IPblock](#task-network-policy---ipblock)
  - [Task: Security context](#task-security-context)
  - [Task: Network policy](#task-network-policy)
  - [Task: security context - rofs](#task-security-context---rofs)
  - [Task: Dockerfile](#task-dockerfile)
  - [Task: Security context - capabilities](#task-security-context---capabilities)
  - [Task: PSS](#task-pss)
  - [Task: Security Context - seccomp](#task-security-context---seccomp)
  - [Task: Ingress](#task-ingress)
  - [task: NP - port](#task-np---port)
  - [Task: kube-bench](#task-kube-bench)

---

## Task: RBAC - clusterrole

Task
A service account named `ci-bot` in the `ci-cd` namespace has been granted excessive permissions that could potentially enable it to create cluster-admin bindings.

Your task is to modify the RBAC configuration as follows:

- Prevent the `ci-bot` service account from binding to any role that has "admin" or "cluster-admin" in its name.
- Ensure that the `service account` **retains its current permissions** within the `ci-cd` namespace.
- Apply this restriction broadly across the entire cluster.
- To achieve this, it may be necessary to delete and recreate the existing role binding with the appropriate restrictions.

---

Service Account Restriction Solution
The current ClusterRole ci-bot-role permits the service account to create and modify role bindings, which poses a risk of privilege escalation.

```sh
k get clusterrolebinding | grep ci-bot
# ci-bot-binding                                                  ClusterRole/ci-bot-role                                                            131m

kubectl describe clusterrole ci-bot-role
# Name:         ci-bot-role
# Labels:       <none>
# Annotations:  <none>
# PolicyRule:
#   Resources                                      Non-Resource URLs  Resource Names  Verbs
#   ---------                                      -----------------  --------------  -----
#   clusterrolebindings.rbac.authorization.k8s.io  []                 []              [create update patch]
#   rolebindings.rbac.authorization.k8s.io         []                 []              [create update patch]
#   configmaps                                     []                 []              [get list watch create update delete]
#   pods                                           []                 []              [get list watch create update delete]
#   services                                       []                 []              [get list watch create update delete]

```

> `clusterrolebindings` and `rolebindings` with `[create update patch]` is excessive permissions

Solution:

Recreate a restricted ClusterRole that omits binding creation permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: ci-bot-role
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterrolebindings", "rolebindings"]
    verbs: ["get", "list", "watch"] # read-only
```

Verify standard operations (expected result: "yes"):

```sh
kubectl auth can-i get pods --as=system:serviceaccount:ci-cd:ci-bot
kubectl auth can-i create deployments --as=system:serviceaccount:ci-cd:ci-bot
```

Verify binding restrictions (expected result: "no"):

```sh
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:ci-cd:ci-bot
kubectl auth can-i create rolebindings
```

---

## Task: falco - find pod

Task
A pod in the `crypto-monitor` namespace is suspected of running crypto-mining software.
Create a Falco rule that detects the execution of known mining processes like `xmrig`, `minerd`, or `cpuminer`.

The rule should be added to `/etc/falco/falco_rules.local.yaml` with below specs:

- Trigger when any of these processes are executed: `xmrig`, `minerd`, `cpuminer`
- Set the priority to `CRITICAL`
- Output the format: `MINING_ALERT: %evt.time,%container.name,%proc.name`
- Tag the events with `[container, crypto_mining, mitre_execution]`

Make sure the rule persists across Falco updates by adding it to the local rules file.

---

- solution

```yaml
# vim /etc/falco/falco_rules.local.yaml
- rule: Detect Crypto Miner
  desc: Detect known crypto mining processes
  condition: >
    evt.type in (execve, execveat)
    and proc.name in (xmrig, minerd, cpuminer)
  output: "MINING_ALERT: %evt.time,%container.name,%proc.name"
  priority: CRITICAL
  tags: [container, crypto_mining, mitre_execution]
```

```sh
systemctl restart falco-modern-bpf

journalctl -u falco-modern-bpf --no-pager | tail -30
```

## Task: Network policy - IPblock

Task
A security team has identified that pods in the `threat-prevention` namespace are attempting to connect to known malicious IP ranges used for command and control servers.

Create a NetworkPolicy that:

- Blocks ALL egress traffic to the following malicious CIDR ranges:
  - `192.168.100.0/24`
  - `10.0.99.0/24`
- Allows DNS traffic (UDP and TCP port 53) to ensure basic network functionality
- Allows all other egress traffic except the blocked malicious ranges
- Applies to all pods in the `threat-prevention` namespace
- The policy should be named block-malicious-egress and should not affect ingress traffic.

---

- solution:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-malicious-egress
  namespace: threat-prevention
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow DNS everywhere
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # Allow everything except malicious CIDRs
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 192.168.100.0/24
              - 10.0.99.0/24
```

---

## Task: Security context

Task
A pod named `secure-app` in the `security-context` namespace is currently running with excessive privileges. The container is capable of escalating privileges and executing as the root user, which presents a significant security risk.

Please modify the pod configuration to achieve the following objectives:

- Prevent privilege escalation
- Ensure the container operates as a non-root user
- Set the user ID to 101 and the group ID to 101
- Utilize the nginxinc/nginx-unprivileged:alpine image
- Configure the container to listen on port 8080

Ensure that the pod remains capable of serving web content on port 8080. You may need to delete and recreate the pod with the appropriate security context.

---

- solution

```yaml
containers:
  - name: secure-app
    image: nginxinc/nginx-unprivileged:alpine
    ports:
      - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 101
      runAsGroup: 101
```

---

## Task: Network policy

Task
The `web-apps` namespace contains a frontend application that should only be accessible from specific sources.

Create a `NetworkPolicy` that:

- Allows ingress traffic on TCP port 80 to pods with label `app: frontend` ONLY from:
  - Pods in the same namespace with label `app: backend`
  - Any pod in the `monitoring` namespace
- Blocks all other ingress traffic to the frontend pods
- Does not affect egress traffic
  The policy should be named `frontend-access` and should apply to the `web-apps` namespace.

Verify that the policy correctly allows and blocks traffic as specified.

---

- solution:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-access
  namespace: web-apps
spec:
  podSelector:
    matchLabels:
      app: frontend

  policyTypes:
    - Ingress

  ingress:
    - from:
        # same namespace: only backend pods
        - podSelector:
            matchLabels:
              app: backend

        # any pod in monitoring namespace
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring

      ports:
        - protocol: TCP
          port: 80
```

---

## Task: security context - rofs

Task
A deployment named `data-processor` in the `immutable-apps` namespace is currently at risk of file system attacks due to the use of a writable root filesystem.

The deployment has the following volumes mounted for writable storage:

- /tmp
- /var/log
- /var/cache/nginx
- /var/run

Your task is to:

- Configure the containers to utilize a read-only root filesystem
- Ensure that the application retains the capability to write to the mounted volumes
- Confirm that the nginx web server remains operational

Please modify the deployment as necessary and test the application's functionality.

---

- solution:

```yaml
containers:
  - name: nginx
    image: nginx
    securityContext:
      readOnlyRootFilesystem: true
```

---

## Task: Dockerfile

Task
A Dockerfile at `/opt/course/image/api-server.Dockerfile` is currently using a full Ubuntu base image with unnecessary packages that increase the attack surface.

Convert the Dockerfile to use a minimal distroless base image by:

- Changing the base image from `ubuntu:20.04` to `gcr.io/distroless/base`
- Removing package managers (apt-get, dpkg) and shell (bash)
- Copying only the necessary application binary
- Setting the non-root user nonroot (UID: 65532)
- Using the exec form for ENTRYPOINT

Do not add any new lines - only modify existing ones. The application binary is a Go binary that listens on port 8080.

---

setup

Original Dockerfile:

```sh
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget python3 python3-pip
RUN useradd -m appuser
COPY ./app-server /app/server
RUN chmod +x /app/server
USER root
ENTRYPOINT /app/server
```

---

Secure Dockerfile:

```sh
FROM gcr.io/distroless/base
COPY --chmod=0755 ./app-server /app/server
USER nonroot:nonroot
ENTRYPOINT ["/app/server"]
```

---

## Task: Security context - capabilities

Task
A pod definition file at `/root/CKS/data-processor.yaml` has excessive Linux capabilities that pose a security risk.

Secure the pod by:

- Dropping `ALL` Linux capabilities by default
- Adding back only the `NET_BIND_SERVICE` capability
- Ensuring the pod can still bind to port 8080
- Generating a `kubesec scan` report after fixing the pod

Once done, generate the report again and save it to `/root/CKS/capabilities-report.txt`

---

- solution

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

---

## Task: PSS

Task
The `financial-apps` namespace contains sensitive financial applications that require strict security controls.

Configure Pod Security Admission to:

- Enforce the restricted policy level on the `financial-apps` namespace
- Use the latest version of the Pod Security Standards
- Add a warning level for the baseline policy to alert on less strict pods
- Label the namespace appropriately for the PSA controller

Verify that the configuration is working by attempting to create a privileged pod and observing the rejection.

---

- solution

```sh
k label ns financial-apps \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite

k get ns financial-apps --show-labels
```

---

## Task: Security Context - seccomp

Task
A security audit identified that containers in the secure-runtime namespace could be vulnerable to process debugging attacks. There is already a pod named secure-app running in this namespace.

Your task is to:

Create a custom seccomp profile that:

- Blocks the `ptrace` and `process_vm_readv` syscalls to prevent process debugging
- Allows all other syscalls to maintain application functionality (use `SCMP_ACT_ALLOW` as the default action)
- Uses `SCMP_ACT_ERRNO` action for the blocked syscalls
- Save the profile as `/var/lib/kubelet/seccomp/profiles/block-debug.json`

Configure the existing secure-app pod to use this custom seccomp profile

Ensure the pod remains functional and can still serve nginx content after applying the seccomp profile

Note: You may need to restart or recreate the pod to apply the seccomp profile changes.

---

```sh
# get node
k -n secure-runtime get po secure-app -o wide

mkdir -p /var/lib/kubelet/seccomp/profiles
vim /var/lib/kubelet/seccomp/profiles/block-debug.json
```

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["ptrace", "process_vm_readv"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

```yaml
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-debug.json
```

---

## Task: Ingress

Task
The `secure-web` namespace contains a web application deployment `secure-app` exposed by a service of the same name.

Create an ingress resource named `secure-ingress` with the following security requirements:

- Route traffic for host `secure-app.company.com` to the backend service on path /
- Enable TLS using the existing secret `web-tls` in the `secure-web` namespace
- Configure the ingress to:
  - Force SSL redirect (HTTP to HTTPS)
  - Use the `nginx` ingress class
  - Add the annotation `nginx.ingress.kubernetes.io/ssl-passthrough: "false"`
    Ensure the ingress only accepts HTTPS traffic
    Verify the ingress is working with TLS termination by testing through the ingress-nginx controller's NodePort.

Note: The ingress-nginx controller uses NodePorts for external access. Use the correct HTTPS NodePort assigned to the ingress-nginx service.

---

- solution:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: secure-web
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "false"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - secure-app.company.com
      secretName: web-tls
  rules:
    - host: secure-app.company.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: secure-app
                port:
                  number: 80
```

---

## task: NP - port

Task
The `external-services` namespace contains applications that need controlled access to external APIs and services.

Create a NetworkPolicy that:

- Allows egress traffic ONLY to specific external services:
  - DNS servers (UDP port 53)
  - HTTPS services (TCP port 443)
  - A specific API endpoint at `api.company.com` (TCP port 8443) - assume this resolves to IP range `192.168.100.0/24`
- Blocks all other egress traffic from the namespace
- Applies to all pods in the `external-services` namespace

The policy should be named `restrict-egress` and should use a CIDR block for the API endpoint.

---

- solution:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: external-services
spec:
  podSelector: {}
  policyTypes:
    - Egress

  egress:
    # DNS anywhere
    - ports:
        - protocol: UDP
          port: 53

    # HTTPS anywhere
    - ports:
        - protocol: TCP
          port: 443

    # api.company.com -> 192.168.100.0/24:8443
    - to:
        - ipBlock:
            cidr: 192.168.100.0/24
      ports:
        - protocol: TCP
          port: 8443
```

---

## Task: kube-bench

Task
Run a CIS Benchmark scan using kube-bench and fix the etcd data directory permission issue.

Tasks:

- Run kube-bench to scan the master components
- Identify the etcd data directory permission violations

Requirements:

- Use kube-bench with appropriate targets to find the issue
- Restrict `etcd` directory permissions to the CIS recommended level
- Apply the fixes recursively to all files and subdirectories
- Verify that the fix resolves the violation

kube-bench is pre-installed. Focus on finding and fixing the etcd data directory permission issue specifically. Note: You may need to apply permissions recursively to ALL possible etcd directories and their contents.

---

```sh
kube-bench run --targets master

chmod -R 700 /var/lib/etcd
```
