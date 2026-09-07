# CKS: Fundamental - Access Control

[back](../README.md)

- [CKS: Fundamental - Access Control](#cks-fundamental---access-control)
  - [Access Control](#access-control)
    - [Admission Controllers](#admission-controllers)

---

## Access Control

When a request reaches the API, it goes through several stages:

1. Authentication
2. Authorization
3. Admission Controllers
4. K8s object

---

### Admission Controllers

- ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

- `admission controller`
  - a **piece of code** that **intercepts requests** to the Kubernetes API server **after** the user is successfully **authenticated and authorized**, but **before** the data is saved to etcd (the cluster's database).

- Two Phases of Admission Control

1. `Mutating Phase`:
   - **modify** or "mutate" the resource object being created or updated.
   - e.g., automatically inject a sidecar proxy container (like Istio) or add default resource limits if a developer forgot to include them.
2. `Validating Phase`:
   - **evaluate** the final version of the object and can only say "yes" or "no".
   - If any single validating controller rejects the request, the entire operation fails, and an error is sent back to the user.
   - This phase happens last so that it can inspect any changes made during the mutating phase.
