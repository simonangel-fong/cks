# CKS: Cluster - `ImagePolicyWebhook` Admission controller

[Back](../README.md)

- [CKS: Cluster - `ImagePolicyWebhook` Admission controller](#cks-cluster---imagepolicywebhook-admission-controller)
  - [`ImagePolicyWebhook` Admission controllers](#imagepolicywebhook-admission-controllers)
    - [How It Works](#how-it-works)
    - [Sample](#sample)
  - [Lab: `ImagePolicyWebhook` Admission controllers (SKip)](#lab-imagepolicywebhook-admission-controllers-skip)

---

## `ImagePolicyWebhook` Admission controllers

- `ImagePolicyWebhook`
  - a built-in Kubernetes **Admission Control plugin** that allows an external backend service to **approve or reject** `container images` before a Pod is allowed to run.

- `kube-apiserver` configuration:
  - flag: `--enable-admission-plugins=ImagePolicyWebhook`
  - and point it to a configuration file.

---

### How It Works

- **Interception**:
  - When you try to create or update a Pod, the `API server` processes authentication and authorization, then sends an **ImageReview JSON request** to your external webhook server.
- **Evaluation**:
  - The external service **checks the image** (such as its **registry**, **tag**, **signature**, or **vulnerability scan results**) against your custom rules.
- **Decision**:
  - The external service **returns an allow or deny** response back to the Kubernetes API server.

---

### Sample

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: "/etc/kubernetes/pki/webhook-kubeconfig"
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
        defaultAllow: true
```

---

## Lab: `ImagePolicyWebhook` Admission controllers (SKip)

- ref: https://github.com/zealvora/certified-kubernetes-security-specialist/blob/main/domain-3-minimize-microservice-vulnerability/imagewebhook.md
