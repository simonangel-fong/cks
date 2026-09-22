# Practices - audit

[Back](../../README.md)

- [Practices - audit](#practices---audit)
  - [Audit: Secret](#audit-secret)
  - [Audit: Pod](#audit-pod)
  - [Audit(killer A)](#auditkiller-a)

---

- Auditing
  - enable Auditing based on the requirements.
  - common flag
    - `--audit-log-path`: Specifies the file path where the audit log is written.
    - `--audit-log-maxage`: Defines the maximum number of days to retain old audit log files before deletion.
    - `--audit-log-maxbackup`: Sets the maximum number of old audit log files to retain.
    - `--audit-log-maxsize`: Specifies the maximum size (in megabytes) of the audit log file before it gets rotated.
  - sample Question
    - Logs should be stored at /var/log/demo-audit.logs
    - Logs should be retained for the next 30 days.
    - Maximum size before rotation should be 500 MB.
    - Maximum number of 10 audit log files should be made available.

## Audit: Secret

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

- enable audit loging

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

## Audit: Pod

- task:
  - enable audit
    - maxsize =7
    - maxbackup =2
    - log path: /var/log/kubernetes/audit/
  - create audit policy
    - path: /etc/kubernetes/audit/audit-policy.yaml
    - resource: `pods`
    - level: `RequestResponse`
    - resource: `pods/log`,`pods/status`
    - level: `Metadata`
    - omitStages: `RequestReceived`

```yaml
# sudo vi /etc/kubernetes/audit/audit-policy.yaml
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods/log", "pods/status"]
```

```sh
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
# - --audit-log-path=/var/log/kubernetes/audit/audit.log

#     volumeMounts:
#     - mountPath: /etc/kubernetes/audit/audit-policy.yaml
#       name: audit
#       readOnly: true
#     - mountPath: /var/log/kubernetes/audit/
#       name: audit-log
#       readOnly: false

#   volumes:
#   - name: audit
#     hostPath:
#       path: /etc/kubernetes/audit/audit-policy.yaml
#       type: File
#   - name: audit-log
#     hostPath:
#       path: /var/log/kubernetes/audit/
#       type: DirectoryOrCreate

```

---

## Audit(killer A)

- task:
  - Audit Logging has been enabled in the cluster with an Audit Policy located at `/etc/kubernetes/audit/policy.yaml`.
  - Change the apiserver setting so that only **one** backup of the logs is stored.
  - Alter the Policy so that it only stores logs:
    - From `Secret` resources, level `Metadata`
    - From `"system:nodes`" userGroups, level `RequestResponse`
    - After you update the Policy, make sure to empty the log file so it only contains entries according to your changes, for example using `echo > /etc/kubernetes/audit/logs/audit.log`.
  - ℹ️ You can use yq to render JSON in a more readable form, for example cat data.json | yq -p json -o json
  - ℹ️ Use sudo -i to become root which may be required for this question

---

- solution:

```yaml
# /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # log Secret resources audits, level Metadata
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]

  # log node related audits, level RequestResponse
  - level: RequestResponse
    userGroups: ["system:nodes"]

  # for everything else don't log anything
  - level: None
```

```sh
sudo -i

cp /etc/kubernetes/manifests/kube-apiserver.yaml \
   /root/kube-apiserver.yaml.bak

vi /etc/kubernetes/manifests/kube-apiserver.yaml

# update apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
# - --audit-log-path=/etc/kubernetes/audit/logs/audit.log
# - --audit-log-maxbackup=1

# empty log
echo > /etc/kubernetes/audit/logs/audit.log

# confirm apiserver
crictl ps | grep apiserver

cat /etc/kubernetes/audit/logs/audit.log
```

> for everything else don't log anything
> `- level: None`
