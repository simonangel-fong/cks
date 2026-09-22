# Practices - RBAC

[Back](../../README.md)

- [Practices - RBAC](#practices---rbac)
  - [Issue a Certificate for a Kubernetes API Client](#issue-a-certificate-for-a-kubernetes-api-client)
  - [RBAC(killer A)](#rbackiller-a)

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
