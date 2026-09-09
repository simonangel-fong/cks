# CKS: Cluster - Admission controller

[Back](../README.md)

- [CKS: Cluster - Admission controller](#cks-cluster---admission-controller)
  - [Admission controllers](#admission-controllers)
    - [default \& explicit admission controller](#default--explicit-admission-controller)
  - [Admission controller: `NameSpaceAutoProvision`](#admission-controller-namespaceautoprovision)
    - [Lab: `NameSpaceAutoProvision`](#lab-namespaceautoprovision)
  - [Admission controller: `PodSecurity`](#admission-controller-podsecurity)
    - [Lab: `PodSecurity` with Pod Security Standard](#lab-podsecurity-with-pod-security-standard)

---

## Admission controllers

- ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

- `admission controller`
  - a **piece of code** that **intercepts requests** to the Kubernetes API server **after** the user is successfully **authenticated and authorized**, but **before** the data is saved to etcd (the cluster's database).

- Two Phases of Admission Control

1. `Mutating Phase`:
   - **modify** or "mutate" the resource object being created or updated.
   - e.g., automatically inject a sidecar proxy container (like Istio) or add default resource limits if a developer forgot to include them.

2. `Validating Phase`:
   - **evaluate** the final version of the object
     - can only say "yes" or "no".
   - If any single validating controller rejects the request, the entire operation fails, and an error is sent back to the user.
   - This phase happens last so that it can inspect any changes made during the mutating phase.

---

### default & explicit admission controller

- default admission controller

```sh
kubectl exec -it kube-apiserver-controlplane -n kube-system -- kube-apiserver -h | grep enable-admission-plugins
      # --enable-admission-plugins strings       admission plugins that should be enabled in addition to default enabled ones (NamespaceLifecycle, LimitRanger, ServiceAccount, TaintNodesByCondition, PodSecurity, Priority, DefaultTolerationSeconds, DefaultStorageClass, StorageObjectInUseProtection, PersistentVolumeClaimResize, RuntimeClass, CertificateApproval, CertificateSigning, ClusterTrustBundleAttest, CertificateSubjectRestriction, DefaultIngressClass, MutatingAdmissionPolicy, MutatingAdmissionWebhook, ValidatingAdmissionPolicy, ValidatingAdmissionWebhook, ResourceQuota). Comma-delimited list of admission plugins: AlwaysAdmit, AlwaysDeny, AlwaysPullImages, CertificateApproval, CertificateSigning, CertificateSubjectRestriction, ClusterTrustBundleAttest, DefaultIngressClass, DefaultStorageClass, DefaultTolerationSeconds, DenyServiceExternalIPs, EventRateLimit, ExtendedResourceToleration, ImagePolicyWebhook, LimitPodHardAntiAffinityTopology, LimitRanger, MutatingAdmissionPolicy, MutatingAdmissionWebhook, NamespaceAutoProvision, NamespaceExists, NamespaceLifecycle, NodeRestriction, OwnerReferencesPermissionEnforcement, PersistentVolumeClaimResize, PodNodeSelector, PodSecurity, PodTolerationRestriction, Priority, ResourceQuota, RuntimeClass, ServiceAccount, StorageObjectInUseProtection, TaintNodesByCondition, ValidatingAdmissionPolicy, ValidatingAdmissionWebhook. The order of plugins in this flag does not matter.

```

- use apiserver flags `--enable-admission-plugins` to declare admission controller explicitly:
  - e.g, `--enable-admission-plugins=NodeRestriction,NamespaceAutoProvision`

---

## Admission controller: `NameSpaceAutoProvision`

- By default,
  - if you attempt to create resources in a nonexistent namespace, you will **immediately encounter an error**.

- `NameSpaceAutoProvision` admission controller:
  - inspects all incoming requests for namespaced resources and **checks** whether the referenced namespace **exists**.
  - If the namespace does not exist, the controller automatically creates it.

---

### Lab: `NameSpaceAutoProvision`

```sh
kubectl get ns unknown-namespace
# Error from server (NotFound): namespaces "unknown-namespace" not found

# no auto ns provision
kubectl run web --image=nginx -n unknown-namespace
# Error from server (NotFound): namespaces "unknown-namespace" not found

# ####################
# enable admission controller
# ####################
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# update:
#     - --enable-admission-plugins=NodeRestriction,NamespaceAutoProvision

# wait for apiserver restart
kubectl get po kube-apiserver-controlplane -n kube-system -w
# NAME                          READY   STATUS    RESTARTS   AGE
# kube-apiserver-controlplane   0/1     Pending   0          38s
# kube-apiserver-controlplane   1/1     Running   0          40s

# confirm
kubectl get ns unknown-namespace
# Error from server (NotFound): namespaces "unknown-namespace" not found
kubectl run web --image=nginx -n unknown-namespace
# pod/web created

kubectl get ns unknown-namespace
# NAME                STATUS   AGE
# unknown-namespace   Active   28s
```

---

## Admission controller: `PodSecurity`

- `PodSecurity` Admission controller
  - enforces Pod Security Standards.
  - it ensures that pods deployed in your cluster **comply with defined security best practices**.

- enable by default.

---

### Lab: `PodSecurity` with Pod Security Standard

- ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#podsecurity

```sh

# Create namespace
kubectl create namespace pod-security-lab
# namespace/pod-security-lab created

# ##############################
# Enforce permissive enforcement
# ##############################
kubectl label namespace pod-security-lab \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest --overwrite
# namespace/pod-security-lab labeled

# confirm
kubectl get ns pod-security-lab --show-labels
# NAME               STATUS   AGE   LABELS
# pod-security-lab   Active   56s   kubernetes.io/metadata.name=pod-security-lab,pod-security.kubernetes.io/enforce-version=latest,pod-security.kubernetes.io/enforce=privileged

# Before: privileged enforcement allows a privileged container.
kubectl run before-pod-security -n pod-security-lab --image=nginx --privileged
# pod/before-pod-security created

# ##############################
# Enforce the baseline Pod Security Standard: warn and audit modes alone do not reject pods.
# ##############################
kubectl label namespace pod-security-lab \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=latest --overwrite
# Warning: existing pods in namespace "pod-security-lab" violate the new PodSecurity enforce level "baseline:latest"
# Warning: before-pod-security: privileged
# namespace/pod-security-lab labeled

# Confirm the enforcement level.
kubectl get namespace pod-security-lab --show-labels
# NAME               STATUS   AGE     LABELS
# pod-security-lab   Active   9m13s   kubernetes.io/metadata.name=pod-security-lab,pod-security.kubernetes.io/enforce-version=latest,pod-security.kubernetes.io/enforce=baseline

# After: the same privileged container configuration is rejected.
kubectl run after-pod-security -n pod-security-lab --image=nginx --privileged
# Error from server (Forbidden): pods "after-pod-security" is forbidden: violates PodSecurity "baseline:latest": privileged (container "after-pod-security" must not set securityContext.privileged=true)

# Confirm the rejected pod was not created.
kubectl get pod after-pod-security -n pod-security-lab
# Error from server (NotFound): pods "after-pod-security" not found

# A pod without the privileged setting passes baseline admission.
kubectl run baseline-web --image=nginx -n pod-security-lab
# pod/baseline-web created

# Clean up the lab namespace and its pods.
kubectl delete namespace pod-security-lab
```

---
