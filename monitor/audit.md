# CKS: Monitoring - Audit

[Back](../README.md)

- [CKS: Monitoring - Audit](#cks-monitoring---audit)
  - [Audit](#audit)
    - [Audit Policy Levels](#audit-policy-levels)
    - [Declarative](#declarative)
    - [Stages](#stages)
  - [Lab: enable auditing](#lab-enable-auditing)
    - [Create policy](#create-policy)
    - [Enable auditing in apiserver](#enable-auditing-in-apiserver)
    - [Test](#test)

---

## Audit

- ref: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/

- `Auditing`
  - provides a security-relevant, chronological set of records documenting the sequence of actions in a cluster.

- **IMPORTANT**:
  - When an event is processed, it's compared against the list of rules **in order**.
    - The **first matching rule sets** the audit level of the event.
    - specific rules first, then generic rules

---

### Audit Policy Levels

- `Audit policy`
  - defines rules about **what events should be recorded** and **what data they should include**.

| Audit Levels      | Description                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `None`            | don't log events that match this rule.                                                                    |
| `Metadata`        | Log request metadata (requesting user, timestamp, resource, verb, etc.) but not request or response body. |
| `Request`         | Log event metadata and request body but not response body.                                                |
| `RequestResponse` | Log event metadata, request and response bodies                                                           |

---

### Declarative

```yaml
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # single resource
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods"]
  # multitple resources
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods/log", "pods/status"]

  # a specific resource
  - level: None
    resources:
      - group: ""
        resources: ["configmaps"]
        resourceNames: ["controller-leader"]

  # a behavior of a user on resources
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: "" # core API group
        resources: ["endpoints", "services"]

  # a group of users on non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
      - "/api*" # Wildcard matching.
      - "/version"

  # namespace
  - level: Request
    resources:
      - group: "" # core API group
        resources: ["configmaps"]
    namespaces: ["kube-system"]

  # more generic rule
  - level: Metadata
    resources:
      - group: "" # core API group
        resources: ["secrets", "configmaps"]

  # resources groups
  - level: Request
    resources:
      - group: "" # core API group
      - group: "extensions" # Version of group should NOT be included.

  # rule level ommit
  - level: Metadata
    omitStages:
      - "RequestReceived"
```

---

### Stages

The kube-apiserver processes request in stages and each stage generates an audit event

| Stage                                                                                                                                              | Description                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `RequestReceived`                                                                                                                                  | When the audit handler receives the request, and before it is delegated down the handler chain. |
| `ResponseStarted` Once the response headers are sent, but before the response body is sent. only generated for long-running requests (e.g. watch). |
| `ResponseComplete`                                                                                                                                 | The response body has been completed and no more bytes will be sent.                            |
| `Panic`                                                                                                                                            | Events generated when a panic occurred.                                                         |

- `omitStages` key: specify stage to be omitted
  - policy level
  - rule level

```yaml
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
omitStages: # policy level
  - "RequestReceived"
rules:
  - level: Metadata
    omitStages: # rule level
      - "RequestReceived"
```

---

## Lab: enable auditing

### Create policy

```sh
# ##############################
# create policy
# ##############################
# policy: no log secrets in kube-system; log secrets metadata in other ns
sudo tee /etc/kubernetes/audit-policy.yaml<<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: None
    resources:
    - group: ""
      resources: ["secrets"]
    namespaces: ["kube-system"]
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]
EOF

```

---

### Enable auditing in apiserver

```yaml
# sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
  labels:
    audit-policy: v1 # trick: change label to automate the apiserver restart
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    # add flags
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    # mount volume
    volumeMounts:
      - name: audit-policy
        mountPath: /etc/kubernetes/audit-policy.yaml
        readOnly: true
      - name: audit-log
        mountPath: /var/log/kubernetes/audit/
        readOnly: false
  # create volume
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File

  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
```

```sh
# confirm apiserver restart
kubectl get po kube-apiserver -n kube-system

```

---

### Test

```sh
# ##############################
# Create secret in kube-system
# ##############################
# Terminal behavior: create secret
kubectl create secret generic test-kube-system -n kube-system --from-literal=key=value
# secret/test-kube-system created
kubectl get secret test-kube-system -n kube-system
# NAME               TYPE     DATA   AGE
# test-kube-system   Opaque   1      29s

# Terminal monitor: stream log
sudo tail -f /var/log/kubernetes/audit/audit.log
# return none
```

```sh
# ##############################
# Create secret in default
# ##############################
# Terminal behavior: create secret
kubectl create secret generic test-default --from-literal=key=value
# secret/test-default created

# Terminal monitor: stream log
sudo tail -f /etc/kubernetes/audit/audit.log
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"8ee17730-f830-446e-bd22-ce212d2536a9","stage":"RequestReceived","requestURI":"/api/v1/namespaces/default/secrets/test-kube-system","verb":"get","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","name":"test-kube-system","apiVersion":"v1"},"requestReceivedTimestamp":"2026-09-13T20:37:21.611127Z","stageTimestamp":"2026-09-13T20:37:21.611127Z"}
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"8ee17730-f830-446e-bd22-ce212d2536a9","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/secrets/test-kube-system","verb":"get","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","name":"test-kube-system","apiVersion":"v1"},"responseStatus":{"metadata":{},"status":"Failure","message":"secrets \"test-kube-system\" not found","reason":"NotFound","details":{"name":"test-kube-system","kind":"secrets"},"code":404},"requestReceivedTimestamp":"2026-09-13T20:37:21.611127Z","stageTimestamp":"2026-09-13T20:37:21.612442Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"kubeadm:cluster-admins\" of ClusterRole \"cluster-admin\" to Group \"kubeadm:cluster-admins\""}}
# ...

# ##############################
# get secret in default
# ##############################
# Terminal behavior: get secret
kubectl get secret
# NAME           TYPE     DATA   AGE
# test-default   Opaque   1      2m39s
kubectl get secret test-default -o yaml

# Terminal monitor: stream log
sudo tail -f /etc/kubernetes/audit/audit.log
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"75ac6b1e-95f4-45b6-beb0-5139e11a522c","stage":"RequestReceived","requestURI":"/api/v1/namespaces/default/secrets?limit=500","verb":"list","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","apiVersion":"v1"},"requestReceivedTimestamp":"2026-09-13T20:40:39.734150Z","stageTimestamp":"2026-09-13T20:40:39.734150Z"}
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"75ac6b1e-95f4-45b6-beb0-5139e11a522c","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/secrets?limit=500","verb":"list","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":200},"requestReceivedTimestamp":"2026-09-13T20:40:39.734150Z","stageTimestamp":"2026-09-13T20:40:39.746369Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"kubeadm:cluster-admins\" of ClusterRole \"cluster-admin\" to Group \"kubeadm:cluster-admins\""}}
```
