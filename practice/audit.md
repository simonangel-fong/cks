# Practices - audit

[Back](../README.md)

- [Practices - audit](#practices---audit)
  - [Audit logging](#audit-logging)

---

## Audit logging

- task:
  - Configurethe api server for audit loggin
  - log path: /etc/kubernetes/audit-logs/audit.log
  - policy path: /etc/kubernetes/audit-policy/policy.yaml
    - None: secret in kube-system
    - Metadata: secret in any ns
  - maxsize =7
  - maxbackup =2

---

- solution

- create policy
```yaml
# vi /etc/kubernetes/audit-policy/policy.yaml
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
```

-  enable audit loging

```sh
vi /etc/kubernetes/manifests/kube-apiserver.yaml
    # - --audit-policy-file=/etc/kubernetes/audit-policy/policy.yaml
    # - --audit-log-path=/etc/kubernetes/audit-logs/audit.log
    # - --audit-log-maxbackup=2
    # - --audit-log-maxsize=7

# volumeMounts:
#   - mountPath: /etc/kubernetes/audit-policy/policy.yaml
#     name: audit
#     readOnly: true
#   - mountPath: /etc/kubernetes/audit-logs
#     name: audit-log
#     readOnly: false

# volumes:
# - name: audit
#   hostPath:
#     path: /etc/kubernetes/audit-policy/policy.yaml
#     type: File

# - name: audit-log
#   hostPath:
#     path: /etc/kubernetes/audit-logs
#     type: DirectoryOrCreate

# confirm
k create secret generic test-secret --from-literal k=v

sudo tail /etc/kubernetes/audit-logs/audit.log -f
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"70607cf4-c644-4642-af31-0d9a173259fe","stage":"RequestReceived","requestURI":"/api/v1/namespaces/default/secrets?fieldManager=kubectl-create\u0026fieldValidation=Strict","verb":"create","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","apiVersion":"v1"},"requestReceivedTimestamp":"2026-09-15T14:26:53.946487Z","stageTimestamp":"2026-09-15T14:26:53.946487Z"}
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"70607cf4-c644-4642-af31-0d9a173259fe","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/secrets?fieldManager=kubectl-create\u0026fieldValidation=Strict","verb":"create","user":{"username":"kubernetes-admin","groups":["kubeadm:cluster-admins","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ffe11c00851ee887ee4007c96b645c769d86f736994385e12ebd8713fec6d1fe"]}},"sourceIPs":["192.168.10.150"],"userAgent":"kubectl/v1.35.8 (linux/amd64) kubernetes/1c2e10a","objectRef":{"resource":"secrets","namespace":"default","name":"test-secret","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestReceivedTimestamp":"2026-09-15T14:26:53.946487Z","stageTimestamp":"2026-09-15T14:26:53.948683Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"kubeadm:cluster-admins\" of ClusterRole \"cluster-admin\" to Group \"kubeadm:cluster-admins\""}}

k create secret generic test-secret --from-literal k=v -n kube-system
sudo tail /etc/kubernetes/audit-logs/audit.log -f
# none

```

