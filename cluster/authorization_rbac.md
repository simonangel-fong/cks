# CKS: Cluster Authorization - RBAC

[Back](../README.md)

- [CKS: Cluster Authorization - RBAC](#cks-cluster-authorization---rbac)
  - [RBAC](#rbac)
    - [Role and RoleBinding - namespace scope](#role-and-rolebinding---namespace-scope)
    - [ClusterRole and ClusterRoleBinding - cluster-wide scope](#clusterrole-and-clusterrolebinding---cluster-wide-scope)
  - [Role](#role)
    - [API Groups](#api-groups)
    - [Resources](#resources)
    - [Verbs](#verbs)
  - [Rolebinding](#rolebinding)
  - [Service Accounts](#service-accounts)
    - [`default` Service Account](#default-service-account)
    - [Connecting to K8s using Token](#connecting-to-k8s-using-token)
  - [Service account security](#service-account-security)
  - [Lab: enable temporary access for a sa](#lab-enable-temporary-access-for-a-sa)
  - [Lab: access api-server within pod](#lab-access-api-server-within-pod)

---

## RBAC

- `RBAC`
  - the built-in security mechanism that regulates **who** can **do what** within a Kubernetes cluster
  - maps **identities** (users, groups, or service accounts) to **permissions** (actions like get, list, create, or delete) on specific **resources** (like pods, services, or deployments).
    - who can do what on what resources

- `Role` defines a **set of permissions**.
- `Subjects` can be `user`, `groups`, `service account`.
- `RoleBinding` ties the **permission** defined in the `role` to `subjects` like Users.

---

### Role and RoleBinding - namespace scope

- `Role`
  - always sets permissions **within a particular namespace.**
- `RoleBinding` associates a `Role` with a user, group, or service account **within a specific namespace**.
  - grants the defined **permissions** to the **subjects** in that namespace

---

### ClusterRole and ClusterRoleBinding - cluster-wide scope

- `ClusterRole`
  - apply across all namespaces in the cluster.
- `ClusterRoleBinding`
  - connects `ClusterRole` to `Subjects`.

---

## Role

- `rules` field:
  - a list of **policies** that define the **permissions** granted by the Role.
  - Each rule specifies which **actions** (verbs) are allowed on which **resources** (API objects).

```sh
kubectl create role pod-reader --verb=list --resource=pods
```

- example

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
  - apiGroups: [""] # "" indicates the core API group
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

---

### API Groups

- `apiGroups` specify which API group **the rule applies to**.

- Kubernetes APIs are categorized into different `API groups`.

  | API Groups        | Description                                                              |
  | ----------------- | ------------------------------------------------------------------------ |
  | "" (empty string) | Refers to the core API group (e.g., pods, services, configmaps etc).     |
  | apps              | Refers to the apps API group (e.g., deployments, daemonsets,replicasets) |
  | batch             | Includes Jobs, CronJobs.                                                 |
  | networking.k8s.io | Handles Ingress and Network Policies.                                    |

---

### Resources

- `resources` field:
  - specifies which Kubernetes resources the **rule applies to**.
  - the resources belong to the specified API group

- command to list resoruce and group

```sh
kubectl api-resources --api-group=""
# NAME                     SHORTNAMES   APIVERSION   NAMESPACED   KIND
# bindings                              v1           true         Binding
# componentstatuses        cs           v1           false        ComponentStatus
# configmaps               cm           v1           true         ConfigMap
# endpoints                ep           v1           true         Endpoints
# events                   ev           v1           true         Event
# limitranges              limits       v1           true         LimitRange
# namespaces               ns           v1           false        Namespace
# nodes                    no           v1           false        Node
# persistentvolumeclaims   pvc          v1           true         PersistentVolumeClaim
# persistentvolumes        pv           v1           false        PersistentVolume
# pods                     po           v1           true         Pod
# podtemplates                          v1           true         PodTemplate
# replicationcontrollers   rc           v1           true         ReplicationController
# resourcequotas           quota        v1           true         ResourceQuota
# secrets                               v1           true         Secret
# serviceaccounts          sa           v1           true         ServiceAccount
# services                 svc          v1           true         Service

kubectl api-resources --api-group="apps"
# NAME                  SHORTNAMES   APIVERSION   NAMESPACED   KIND
# controllerrevisions                apps/v1      true         ControllerRevision
# daemonsets            ds           apps/v1      true         DaemonSet
# deployments           deploy       apps/v1      true         Deployment
# replicasets           rs           apps/v1      true         ReplicaSet
# statefulsets          sts          apps/v1      true         StatefulSet

kubectl api-resources --api-group="batch"
# NAME       SHORTNAMES   APIVERSION   NAMESPACED   KIND
# cronjobs   cj           batch/v1     true         CronJob
# jobs                    batch/v1     true         Job

kubectl api-resources --api-group="networking.k8s.io"
# NAME              SHORTNAMES   APIVERSION             NAMESPACED   KIND
# ingressclasses                 networking.k8s.io/v1   false        IngressClass
# ingresses         ing          networking.k8s.io/v1   true         Ingress
# networkpolicies   netpol       networking.k8s.io/v1   true         NetworkPolicy

```

---

### Verbs

- `Verb`
  - specifies **what actions** (operations) are **allowed** on the specified resources.

| Common Verbs | Description                      |
| ------------ | -------------------------------- |
| get          | Read a specific resource.        |
| list         | List all resources of that type. |
| create       | Create a new resource.           |
| delete       | Modify an existing resource.     |
| update       | Remove a resource.               |
| watch        | Observe changes to a resource    |

---

## Rolebinding

```sh
kubectl create rolebinding pod-reader --role=pod-reader --user=bob
```

- sample

```yaml
apiVersion: rbac.authorization.k8s.io/v1
# This role binding allows "jane" to read pods in the "default" namespace.
# You need to already have a Role named "pod-reader" in that namespace.
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
  - kind: User
    name: jane # bind a user
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role # Role
  name: pod-reader # sa
  apiGroup: rbac.authorization.k8s.io
```

---

## Service Accounts

Kubernetes Clusters have two categories of accounts:

| User         | account type     | authentication | rolebinding                                                   |
| ------------ | ---------------- | -------------- | ------------------------------------------------------------- |
| Humans       | User Accounts    | certificate    | `kubectl create rolebinding admin --user=<user_name>`         |
| Applications | Service Accounts | sa token       | `kubectl create rolebinding admin --serviceaccount=<sa_name>` |

- A Pod can use ita **token** associated with the **service account** to perform some actions on Kubernetes cluster.
  - each Pod will receive different set of tokens, even using the same sa.

---

### `default` Service Account

- created for every namespace
- default permission:
  - API discovery permissions
  - no other permissions
- assign to Pod in a namespace if not manually assign a ServiceAccount
- `Service Account Token` gets **mounted** inside the Pod inside the `/var/run` directory and can easily be accessed using cat command.

```sh
cat /var/run/secrets/kubernetes.io/serviceaccount
```

### Connecting to K8s using Token

- Using the `Service Account Token`, you can connect to the Kubernetes Cluster to perform operations.

- ref: https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/

```sh
# Point to the internal API server hostname
APISERVER=https://kubernetes.default.svc

# Path to ServiceAccount token
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

# Read this Pod's namespace
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)

# Read the ServiceAccount bearer token
TOKEN=$(cat ${SERVICEACCOUNT}/token)

# Reference the internal certificate authority (CA)
CACERT=${SERVICEACCOUNT}/ca.crt

# Explore the API with TOKEN
curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api
```

---

## Service account security

- keep `default` service account **minimal permission**.
  - `defautl` sa will be assigned to pod
  - if the default service account is granted excessive permissions, all pods using it will inherit those privileges, potentially leading to security risks.

- can opt out of automounting the credentials inside the pods
  - SA level
    - manifest: `automountServiceAccountToken: false`
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: build-robot
    automountServiceAccountToken: false
    ```
  - Pod level
    - manifest: `automountServiceAccountToken: false`
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: my-pod
    spec:
      serviceAccountName: build-robot
      automountServiceAccountToken: false
    ```

---

Precedence of Auto-Mounting Settings when:

- 1. Service Account Level: Auto Mounting = false
- 2. POD Level: Auto Mounting = True

If **both** the `pod` specification and the `service account` define `automountServiceAccountToken`, the **pod-level** setting takes **precedence**.

---

## Lab: enable temporary access for a sa

```sh
# ###############################
# Create role, sa, rolebinding
# ###############################

# create a role: read pods
kubectl create role test --verb=get,list,watch --resource=pods
# role.rbac.authorization.k8s.io/test created

# confirm
kubectl describe role test
# Name:         test
# Labels:       <none>
# Annotations:  <none>
# PolicyRule:
#   Resources  Non-Resource URLs  Resource Names  Verbs
#   ---------  -----------------  --------------  -----
#   pods       []                 []              [get list watch]


# create a test sa
kubectl create sa test-sa
# serviceaccount/test-sa created

# confirm
kubectl describe sa test-sa
# Name:                test-sa
# Namespace:           default
# Labels:              <none>
# Annotations:         <none>
# Image pull secrets:  <none>
# Mountable secrets:   <none>
# Tokens:              <none>
# Events:              <none>

# create a rolebinding
kubectl create rolebinding test --role=test --serviceaccount=default:test-sa
# rolebinding.rbac.authorization.k8s.io/test created

# confirm
kubectl describe rolebinding
# Name:         test
# Labels:       <none>
# Annotations:  <none>
# Role:
#   Kind:  Role
#   Name:  test
# Subjects:
#   Kind            Name     Namespace
#   ----            ----     ---------
#   ServiceAccount  test-sa  default


# ###############################
# Create token for authentication
# ###############################
# authentication: create a token for sa with duration
TOKEN=$(kubectl create token test-sa --duration=48h)


# ###############################
# test
# ###############################
# create workload
kubectl create deploy web-app --image=nginx --replicas=3
# deployment.apps/web-app created

# get cluster ip
kubectl cluster-info
# Kubernetes control plane is running at https://192.168.10.150:6443
# CoreDNS is running at https://192.168.10.150:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# query as test-sa
# list pods
curl -X GET https://192.168.10.150:6443/api/v1/namespaces/default/pods    \
    --header "Authorization: Bearer $TOKEN"   \
    --cacert /etc/kubernetes/pki/apiserver.crt  \
    --key /etc/kubernetes/pki/apiserver.key

# {
#   "kind": "PodList",
#   "apiVersion": "v1",
#   "metadata": {
#     "resourceVersion": "25399"
#   },
#   "items": [
#     {
#       "metadata": {
#         "name": "web-app-6964d6c6c9-6r8mq",
#         "generateName": "web-app-6964d6c6c9-",

# list deployments: forbidden
curl -X GET https://192.168.10.150:6443/apis/apps/v1/namespaces/default/deployments    \
    --header "Authorization: Bearer $TOKEN"   \
    --cacert /etc/kubernetes/pki/apiserver.crt  \
    --key /etc/kubernetes/pki/apiserver.key

# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "deployments.apps is forbidden: User \"system:serviceaccount:default:test-sa\" cannot list resource \"deployments\" in API group \"apps\" in the namespace \"default\"",
#   "reason": "Forbidden",
#   "details": {
#     "group": "apps",
#     "kind": "deployments"
#   },
#   "code": 403
```

---

## Lab: access api-server within pod

```sh
# ####################
# create a pod
# ####################
kubectl run web --image=nginx
# pod/web created

# confirm default sa and mount
kubectl describe pod web | grep -iE "serviceaccount|service account"
# Service Account:  default
#       /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-hngmv (ro)

# exec
kubectl exec -it web -- bash

# access sa mount
ls /var/run/secrets/kubernetes.io/serviceaccount/
# ca.crt  namespace  token

cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt; echo
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo
# default
cat /var/run/secrets/kubernetes.io/serviceaccount/token; echo


# Point to the internal API server hostname
APISERVER=https://kubernetes.default.svc

# Path to ServiceAccount token
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

# Read this Pod's namespace
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)

# Read the ServiceAccount bearer token
TOKEN=$(cat ${SERVICEACCOUNT}/token)

# Reference the internal certificate authority (CA)
CACERT=${SERVICEACCOUNT}/ca.crt

# Explore the API with TOKEN
curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api
# {
#   "kind": "APIVersions",
#   "versions": [
#     "v1"
#   ],
#   "serverAddressByClientCIDRs": [
#     {
#       "clientCIDR": "0.0.0.0/0",
#       "serverAddress": "192.168.10.150:6443"
#     }
#   ]
# }


# list api resources
curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1
# {
#   "kind": "APIResourceList",
#   "groupVersion": "v1",
#   "resources": [
#     {
#       "name": "bindings",
#       "singularName": "binding",
#       "namespaced": true,
#       "kind": "Binding",
#       "verbs": [
#         "create"
#       ]
#     },
#     {
#       "name": "componentstatuses",
#       "singularName": "componentstatus",
#       "namespaced": false,

```
