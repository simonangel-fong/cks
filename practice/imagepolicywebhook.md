# Practices - ImagePolicyWebhook

[Back](../README.md)

- [Practices - ImagePolicyWebhook](#practices---imagepolicywebhook)
  - [ImagePolicyWebhook](#imagepolicywebhook)

---

## ImagePolicyWebhook

- task an `ImagePolicyWebhook` setup has been half finished, complete it
  - `admission_config.json` points to correct kubeconfig
  - set `allow=100`
  - all pod creation should be prevented if external service is not reachable
  - the exteranal service will be reachable under `https://localhost:1234` in the future
  - register the corret admission plugin in the apiserver

---

- solution
  - ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook

- `/etc/kubernetes/policywebhook/admission.json`

```yaml
{
  "apiVersion": "apiserver.config.k8s.io/v1",
  "kind": "AdmissionConfiguration",
  "plugins":
    [
      {
        "name": "ImagePolicyWebhook",
        "configuration":
          {
            "imagePolicy":
              {
                "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
                "allowTTL": 100,
                "denyTTL": 50,
                "retryBackoff": 500,
                "defaultAllow": false,
              },
          },
      },
    ],
}
```

- ref: https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/

```yaml
# inspet config
# sudo vi /etc/kubernetes/policywebhook/kubeconfig
apiVersion: v1
kind: Config
clusters:
  - cluster:
      certificate-authority: /etc/kubernetes/pki/ca/crt
      server: https://localhost:1234
    name: image-checker
contexts:
  - context:
      cluster: webhook
    name: webhook-context
current-context: webhook-context
```

- override apiserver

```sh
sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/policywebhook/admission.json
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
```

- test

```sh
k run po --image=nginx
```
