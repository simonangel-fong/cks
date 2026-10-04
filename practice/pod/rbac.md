# Practices - RBAC

[Back](../../README.md)

- [Practices - RBAC](#practices---rbac)
  - [Shortcut](#shortcut)
  - [Issue a Certificate for a Kubernetes API Client](#issue-a-certificate-for-a-kubernetes-api-client)
  - [RBAC(killer A)](#rbackiller-a)
  - [CSR(killer B)](#csrkiller-b)
  - [Task: SA - role](#task-sa---role)
  - [Task: RBAC - role](#task-rbac---role)
  - [Task: RBAC - clusterrole](#task-rbac---clusterrole)
  - [SA, RBAC role](#sa-rbac-role)
  - [RBAC - role](#rbac---role)
  - [SA, RBAC, security context](#sa-rbac-security-context)
  - [RBAC - clusterrole](#rbac---clusterrole)

---

## Shortcut

- Create a KEY
- Create a CSR for that KEY
- Create a CRT by signing the CSR using the CA of the cluster

```sh
# create private key
openssl genrsa -out server.key 4096
# create csr
openssl req -new -key server.key -out server.csr -subj "/CN=mydomain.com/O=MyCompany"
openssl req -in server.csr -noout -text -verify
# create crt: self-signed
openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365
openssl x509 -in server.crt -noout -text

```

---

## Issue a Certificate for a Kubernetes API Client

- context:
  - cluster created with `kubeadm`

- task:
  - create a CSR for a new user named `bob` as `developer` who can list, get and run pod in `app` ns
  - sign the csr with cluster CA
  - create RBAC for user `bob`
  - confirm permission for `bob`

---

- solution

```sh
# Create a private key
openssl genrsa -out bob.key 3072
# create csr
openssl req -new -key bob.key -out bob.csr -subj "/CN=bob/O=developer"

# Encode the CSR document
cat bob.csr | base64 | tr -d "\n"; echo
# LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ1p6Q0NBVThDQVFBd0lqRU1NQW9HQTFVRUF3d0RZbTlpTVJJd0VBWURWUVFLREFsa1pYWmxiRzl3WlhJdwpnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFET0NuTllrUTNxQk14TngwYU9oVC9tCm9mRVRUOWZnUEUzM2o1N3FJSVl0VXJ4K3JjSnlCOWJLeGZIb3NDSGxKSWsyeWNza2pMSm90bVdGRWRHeWErY2EKU0IvYklRTVRJWmtwSEdZL0NVOUxwZUhGTVhBYUVQWkJab0NRazJSTUVUYUVZMS9FcjVkL3BjUGY0VDVnU1QyawpQU3BnSGtkdy9DOXF5VFZ2RXdiVWZ4czFwQkhvMkcrdW51L2F3WnBBVDVNOWJFekVxcUlvU1AxanQxVnNSeFZBCjdPdkxYTFRjTFBjQmV5QXNJWW9qTzk5WjVOQmhTQ1EyZ3VrcjlpWnQzQnczbC9xQmxYb0NCeW9OWms5c291d1gKL1l6WkVEcWxmOEVQVGMzUHFJWGxDZllJcXlvOW9Ycjh2ZHJzemw5cllKZkVIOHVCMzVWOGc2alJxQU5YRHBNZgpBZ01CQUFHZ0FEQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFGOXRGeG13MHRvcjVWNnFPOWZzQk1DK3Z5SW9pCjdEYXJYS2dzZ09qQnNuS3dzbjFLYUFTSmJnRlRhVEd0eUJVakE4SUhocTZFd2pBeDJpSGF2MVBuM2xmTlVxRXUKR0FTZVRob3NTcE9yS0ZNYXEyUlJlbndCRlpHZzFEbHVoc1F6SjJCNzJiYkgrYWE2TXY0WE5Sa2Nhc09kazlsYQpxNFljc3oxNkIzbW1TZS9rUFFPK2dJNy9tY1dGTEZJdzh2MUdjTzdzZ3NzaVluTUYwcnZDTVdKZXpGTTNTYnF5ClZNOGRHRXljREZqT2gxSEZ2aU1KL3p1SXlaVzViSTdVSGQ5MDFIaTN3VlZTMzhPRldzZ3hRM3NmQlJmMk1CSjUKTS9xNXdUT3JNZ3R3bXJpV0lwSS9YeU5kdUJEanVVdi8waUJwQUtTMEg5c0RMWTVDeWh5WXZJZUM1UT09Ci0tLS0tRU5EIENFUlRJRklDQVRFIFJFUVVFU1QtLS0tLQo=

# create csr in cluster
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: bob
spec:
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ1p6Q0NBVThDQVFBd0lqRU1NQW9HQTFVRUF3d0RZbTlpTVJJd0VBWURWUVFLREFsa1pYWmxiRzl3WlhJdwpnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFET0NuTllrUTNxQk14TngwYU9oVC9tCm9mRVRUOWZnUEUzM2o1N3FJSVl0VXJ4K3JjSnlCOWJLeGZIb3NDSGxKSWsyeWNza2pMSm90bVdGRWRHeWErY2EKU0IvYklRTVRJWmtwSEdZL0NVOUxwZUhGTVhBYUVQWkJab0NRazJSTUVUYUVZMS9FcjVkL3BjUGY0VDVnU1QyawpQU3BnSGtkdy9DOXF5VFZ2RXdiVWZ4czFwQkhvMkcrdW51L2F3WnBBVDVNOWJFekVxcUlvU1AxanQxVnNSeFZBCjdPdkxYTFRjTFBjQmV5QXNJWW9qTzk5WjVOQmhTQ1EyZ3VrcjlpWnQzQnczbC9xQmxYb0NCeW9OWms5c291d1gKL1l6WkVEcWxmOEVQVGMzUHFJWGxDZllJcXlvOW9Ycjh2ZHJzemw5cllKZkVIOHVCMzVWOGc2alJxQU5YRHBNZgpBZ01CQUFHZ0FEQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFGOXRGeG13MHRvcjVWNnFPOWZzQk1DK3Z5SW9pCjdEYXJYS2dzZ09qQnNuS3dzbjFLYUFTSmJnRlRhVEd0eUJVakE4SUhocTZFd2pBeDJpSGF2MVBuM2xmTlVxRXUKR0FTZVRob3NTcE9yS0ZNYXEyUlJlbndCRlpHZzFEbHVoc1F6SjJCNzJiYkgrYWE2TXY0WE5Sa2Nhc09kazlsYQpxNFljc3oxNkIzbW1TZS9rUFFPK2dJNy9tY1dGTEZJdzh2MUdjTzdzZ3NzaVluTUYwcnZDTVdKZXpGTTNTYnF5ClZNOGRHRXljREZqT2gxSEZ2aU1KL3p1SXlaVzViSTdVSGQ5MDFIaTN3VlZTMzhPRldzZ3hRM3NmQlJmMk1CSjUKTS9xNXdUT3JNZ3R3bXJpV0lwSS9YeU5kdUJEanVVdi8waUJwQUtTMEg5c0RMWTVDeWh5WXZJZUM1UT09Ci0tLS0tRU5EIENFUlRJRklDQVRFIFJFUVVFU1QtLS0tLQo=
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
# certificatesigningrequest.certificates.k8s.io/bob created

# admin
kubectl get csr
# NAME        AGE    SIGNERNAME                                    REQUESTOR                  REQUESTEDDURATION   CONDITION
# bob         43s    kubernetes.io/kube-apiserver-client           kubernetes-admin           24h                 Pending

# approve
kubectl certificate approve bob
# certificatesigningrequest.certificates.k8s.io/bob approved

# confirm
kubectl get csr bob
# NAME   AGE     SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
# bob    8m17s   kubernetes.io/kube-apiserver-client   kubernetes-admin   24h                 Approved,Issued

# Get the certificate
kubectl get csr/bob -o yaml
kubectl get csr bob -o jsonpath='{.status.certificate}'| base64 -d > bob.crt

# Configure the certificate into kubeconfig
kubectl config set-credentials bob --client-key=bob.key --client-certificate=bob.crt --embed-certs=true
# User "bob" set.

# add user to context
kubectl config set-context bob --cluster=kubernetes --user=bob
# Context "bob" created.

# test
kubectl --context bob auth whoami
# ATTRIBUTE                                           VALUE
# Username                                            bob
# Groups                                              [developer system:authenticated]
# Extra: authentication.kubernetes.io/credential-id   [X509SHA256=4155bb96eb0e8f09b34395262b69d02793074130628061c4ce10eba82513af6d]
```

- Create Role and RoleBinding

```sh
kubectl config use-context kubernetes-admin@kubernetes
# Switched to context "kubernetes-admin@kubernetes".

kubectl create namespace app
# namespace/app created

# create role
kubectl create role developer -n app --verb=create,get,list --resource=pods
# role.rbac.authorization.k8s.io/developer created

# creat rolebinding
kubectl create rolebinding developer-binding-bob -n app --role=developer --user=bob
# rolebinding.rbac.authorization.k8s.io/developer-binding-bob created

# test as bob
kubectl config use-context bob
# Switched to context "bob".

# confirm permission
kubectl auth can-i list pod -n app
# yes
kubectl auth can-i get pod -n app
# yes
kubectl auth can-i create pod -n app
# yes
kubectl auth can-i update pod -n app
# no
kubectl auth can-i delete pod -n app
# no

kubectl run web -n app --image=nginx
# pod/web created
kubectl get po -n app
# NAME   READY   STATUS    RESTARTS   AGE
# web    1/1     Running   0          19s
kubectl delete po web -n app
# Error from server (Forbidden): pods "web" is forbidden: User "bob" cannot delete resource "pods" in API group "" in the namespace "app"
```

---

## RBAC(killer A)

Solve this question on: ssh cks3477

- task:
  - You're asked to implement some RBAC for user `gianna`:
    - There are existing cluster-level RBAC resources in place to, among other things, ensure that user `gianna` can never **read** Secret contents **cluster-wide**. Confirm this is correct or restrict the existing RBAC resources to ensure this.
    - In addition, create more RBAC resources to allow user `gianna` to **create** `Pods` and `Deployments` in Namespaces `security`, restricted and internal. It's likely the user will receive these exact permissions as well for other Namespaces in the future.
  - To test your RBAC you can:
    - Switch to the other context with:

    ```sh
    k config use-context gianna@infra-prod
    ```

  - And afterwards switch back to the default context with:

    ```sh
    k config use-context kubernetes-admin@kubernetes
    ```

---

- solution:

```sh
# confirm
kubectl edit clusterrole gianna
# remove
# - secrets
kubectl auth can-i get secrets -A --as=gianna
kubectl auth can-i list secrets -A --as=gianna
kubectl auth can-i watch secrets -A --as=gianna

k create clusterrole gianna-additional --verb=create --resource=pods --resource=deployments

k -n security create rolebinding gianna-additional --clusterrole=gianna-additional --user=gianna
k -n restricted create rolebinding gianna-additional --clusterrole=gianna-additional --user=gianna
k -n internal create rolebinding gianna-additional --clusterrole=gianna-additional --user=gianna
```

---

## CSR(killer B)

- task:
  - Create and approve the `CertificateSigningRequest` from `/course/9/csr-app-6c63ce3f.yaml`, then download the decoded certificate to `/course/9/app-6c63ce3f.crt`.
  - Create and deny the `CertificateSigningRequest` from `/course/9/csr-app-dc6fdc2d.yaml`, then store the kubectl describe output from that resource at `/course/9/csr-app-dc6fdc2d.log`.
  - Using the template below, create a `CertificateSigningRequest` YAML for `/course/9/new.csr` and store it at `/course/9/new.csr.yaml`. The NAME should be the same as the CN subject of the new.csr file.

```txt
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: {{NAME}}
spec:
  groups:
  - system:authenticated
  request: {{REQUEST}}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
```

---

- solution

```sh
# create csr
k -f /course/9/csr-app-6c63ce3f.yaml create
# confirm
k get csr

# approve
kubectl certificate approve app-6c63ce3f@users-pro
# confirm
k get csr

# get cert
k get csr app-6c63ce3f@users-pro -ojsonpath="{.status.certificate}" | base64 -d > /course/9/app-6c63ce3f.crt

```

```sh
# create csr
k -f /course/9/csr-app-dc6fdc2d.yaml create
# confirm
k get csr

# deny
k certificate deny app-dc6fdc2d@users-base
# confirm
k get csr

# write
k describe csr app-dc6fdc2d@users-base > /course/9/csr-app-dc6fdc2d.log


```

```sh
# read csr
cat /course/9/new.csr

# get cn, o
openssl req -in /course/9/new.csr -noout -text
# Subject: CN = app-c5a95f65@users-company

# encode
cat /course/9/new.csr | base64 | tr -d "\n"


vi /course/9/new.csr.yaml
# apiVersion: certificates.k8s.io/v1
# kind: CertificateSigningRequest
# metadata:
#   name: app-c5a95f65@users-company
# spec:
#   groups:
#   - system:authenticated
#   request: encode_csr
#   signerName: kubernetes.io/kube-apiserver-client
#   usages:
#   - client auth
```

---

## Task: SA - role

A pod has been created in the `omni` namespace, but it has a few issues that need to be addressed.

- The pod has been created with more permissions than it needs.
- It allows read access to the `/usr/share/nginx/html/internal` directory, making the Internal Site publicly accessible.

To verify this, click the Site button (above the terminal) and add `/internal/` to the end of the URL.

Use the below recommendations to resolve this.

- Use the `AppArmor` profile created at `/etc/apparmor.d/frontend` to restrict access to the internal site.
- The `omni` namespace has several `service accounts`. Apply the principle of least privilege and use the service account with the minimum privileges (excluding the default service account).
- Once the pod is recreated with the correct service account, delete the other unused service accounts in the omni namespace (excluding the default service account).
- Do not create a new service account or use the default service account.

---

- **Solution**

```sh
apparmor_parser -q /etc/apparmor.d/frontend
```

The profile name used by this file is `restricted-frontend` (open the `/etc/apparmor.d/frontend` file to check).

To verify that the profile was successfully loaded, use the aa-status command:

```sh
aa-status | grep restricted-frontend
  #  restricted-frontend
```

The pod should only use the service account called `frontend-default` as it has the least privileges of all the service accounts in the `omni` namespace (excluding default)
The other service accounts, fe and `frontend` have additional permissions (check the `roles` and `rolebindings` associated with these accounts)

Use the below YAML file to re-create the frontend-site pod after deleting the original frontend-site pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: frontend-site
  namespace: omni
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: restricted-frontend
  serviceAccountName: frontend-default #Use the service account with least privileges
  containers:
    - image: nginx:alpine
      name: nginx
      volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: test-volume
  volumes:
    - name: test-volume
      hostPath:
        path: /data/pages
        type: Directory
```

Alternatively, you can also use the edit command to edit the running pod definition:

```sh
kubectl edit pod frontend-site -n omni
```

Then delete the frontend-site pod and apply the file saved in the /tmp folder after editing like the one shown here:

A copy of your changes has been stored to "/tmp/kubectl-edit-3250548530.yaml"

Next, Delete the unused service accounts in the 'omni' namespace.

```sh
kubectl -n omni delete sa frontend
kubectl -n omni delete sa fe
```

---

## Task: RBAC - role

A developer named martin needs access to work on the `dev-a`, `dev-b`, and `dev-z` namespaces. He should have the ability to carry out any operation on any pod in the `dev-a` and `dev-b` namespaces. However, on the `dev-z` namespace, he should only have the permission to get and list the pods.

The current setup is too permissive and violates the above condition. Use the above requirement and secure martin's access in the cluster. You may re-create objects; however, ensure to use the same names as the ones in currently in effect.

---

- **Solution**

```sh
kubectl auth can-i --list --as=martin -n dev-a
kubectl auth can-i --list --as=martin -n dev-b
kubectl auth can-i --list --as=martin -n dev-z

# corret rolebinding or clusterrolebinding
# dev-a and dev-b: pods, verbs ["*"]
# dev-z: pods, verbs ["get", "list"]
```

> all permission: verbs="\*"

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

1. Update the Staging Database Role
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

1. Update the Backup Database Role
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

---

## RBAC - clusterrole

Task
A security team needs cross-namespace monitoring capabilities with restricted permissions. Create RBAC resources that allow a ServiceAccount to read pods across multiple namespaces while following the principle of least privilege.

Requirements:

- Create a ServiceAccount named `cluster-monitor` in the `monitoring-ns` namespace
- Create a ClusterRole named `pod-reader-clusterrole` that allows get, list, and watch operations on pods
- Grant the ServiceAccount access only in the `monitoring-ns` and `apparmor-demo` namespaces
- Label the `monitoring-ns` and `apparmor-demo` namespaces with `monitoring: enabled`
- Create a RoleBinding named `cross-namespace-monitor` in each of the allowed namespaces (`monitoring-ns` and `apparmor-demo`) that references the ClusterRole
  Note: Use namespace-scoped RoleBindings (not ClusterRoleBinding) to restrict access to only the specified namespaces.

Ensure the ServiceAccount has the minimum required permissions following the principle of least privilege.

---

- solution

```sh
# sa
kubectl create sa cluster-monitor -n monitoring-ns

# clusterrole
kubectl create clusterrole pod-reader-clusterrole --verb=get,list,watch --resource=pods

# rolebinding
kubectl create rolebinding cross-namespace-monitor -n monitoring-ns --clusterrole=pod-reader-clusterrole   --serviceaccount=monitoring-ns:cluster-monitor

kubectl create rolebinding cross-namespace-monitor -n apparmor-demo --clusterrole=pod-reader-clusterrole   --serviceaccount=monitoring-ns:cluster-monitor

# label
kubectl label ns monitoring-ns monitoring=enabled --overwrite
kubectl label ns apparmor-demo monitoring=enabled --overwrite
```

---
