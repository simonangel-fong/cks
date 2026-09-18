# Practices - Admission

[Back](../README.md)

- [Practices - Admission](#practices---admission)
  - [Admission: PSA \& PSS](#admission-psa--pss)
  - [Admission: Image Policy Webhook](#admission-image-policy-webhook)
  - [Admission: `NodeRestriction`](#admission-noderestriction)
  - [ImagePolicyWebhook](#imagepolicywebhook)

---

- Pod Security Standards
  - clear understanding of pod security standards, including how to implement and adjust PSS configurations for pods and deployments

api server flag: `--enable-admission-plugins`

## Admission: PSA & PSS

- ref:
  - https://kubernetes.io/docs/concepts/security/pod-security-admission/#pod-security-admission-labels-for-namespaces
  - https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
- task:
  - enable `pod security admission`
  - create ns `prod`
  - enforce `restricted` security statnd on ns `prod`

```sh
# enable psa
vi /etc/kubernetes/manifests/kube-apiserver.yaml
#     - --enable-admission-plugins=PodSecurity

k create ns prod
k label namespace prod pod-security.kubernetes.io/enforce=baseline

# test
k run test -n prod --image=nginx --privileged
# Error from server (Forbidden): pods "test" is forbidden: violates PodSecurity "baseline:latest": privileged (container "test" must not set securityContext.privileged=true)

```

---

## Admission: Image Policy Webhook

- task:
  - enable image policy webhook admission
  - config

- setup env

```sh
sudo apt install python3-pip -y
sudo apt install python3-venv -y

mkdir -pv imagepolicywebhook
cd imagepolicywebhook

python3 -m venv .venv
source .venv/bin/activate
pip3 install flask

cd ~/imagepolicywebhook

tee image_policy_webhook.py<<EOF
from flask import Flask, request, jsonify

app = Flask(__name__)

# Only allow nginx and httpd images
ALLOWED_IMAGES = {"nginx", "httpd"}

@app.route('/validate', methods=['POST'])
def validate():
    request_data = request.get_json()

    # Extract container images
    allowed = True
    for container in request_data.get("spec", {}).get("containers", []):
        image = container.get("image", "").split(":")[0]  # Ignore tag
        if image not in ALLOWED_IMAGES:
            allowed = False
            break

    response = {
        "apiVersion": "imagepolicy.k8s.io/v1alpha1",
        "kind": "ImageReview",
        "status": {
            "allowed": allowed
        }
    }

    return jsonify(response)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080, debug=True)
EOF

python3 image_policy_webhook.py

sudo tee /etc/systemd/system/image-policy-webhook.service<<EOF
[Unit]
Description=Kubernetes Image Policy Webhook Service
After=network.target

[Service]
Type=simple
User=ubuntuadmin
WorkingDirectory=/home/ubuntuadmin/imagepolicywebhook
ExecStart=/home/ubuntuadmin/imagepolicywebhook/.venv/bin/python image_policy_webhook.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF


sudo systemctl daemon-reload
sudo systemctl enable --now image-policy-webhook.service
sudo systemctl status image-policy-webhook.service
# sudo journalctl -u image-policy-webhook.service -f

# create kubeconfig
sudo tee /etc/kubernetes/pki/webhook-kubeconfig  <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: http://127.0.0.1:8080/validate
  name: webhook
contexts:
- context:
    cluster: webhook
  name: webhook-context
current-context: webhook-context
EOF

```

- solution

```yaml
# sudo vi /etc/kubernetes/pki/admission.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: /etc/kubernetes/pki/webhook-kubeconfig
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
        defaultAllow: true
```

```sh
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/pki/admission.yaml
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook

# test
k run test-nginx --image=nginx
k run test-httpd --image=httpd
k run test-busybox --image=busybox --command -- sleep 3600
# Error from server (Forbidden): pods "test-busybox" is forbidden: one or more images rejected by webhook backend
```

---

## Admission: `NodeRestriction`

- task:
  - enable `NodeRestriction` admission controller
  - verify by adding the label `node-restrition.kubernetes.io/two=123` from `node01` to `node01`

---

- solution
  - ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction

```sh
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --enable-admission-plugins=NodeRestriction,NamespaceLifecycle

# ####################
# label from node01
# ####################
# label current node as control-plane
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 node-role.kubernetes.io/control-plane="" --overwrite
# Error from server (Forbidden): nodes "worker-node-01" is forbidden: User "system:node:node01" cannot get resource "nodes" in API group "" at the cluster scope: node 'node01' cannot read 'worker-node-01', only its own Node object

# label current node as restiction
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 node-restriction.kubernetes.io/="" --overwrite
# Error from server (Forbidden): nodes "node01" is forbidden: is not allowed to modify labels: node-restriction.kubernetes.io/

# label controlplane node
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node controlplane new-label="123" --overwrite
# Error from server (Forbidden): nodes "controlplane" is forbidden: User "system:node:node01" cannot get resource "nodes" in API group "" at the cluster scope: node 'node01' cannot read 'controlplane', only its own Node object

# label current node a new label
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node node01 new-label="123" --overwrite
# node/node01 labeled

# ####################
# label from controlplane
# ####################
# label node01
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf label node node01 node-role.kubernetes.io/control-plane="" --overwrite
# node/node01 labeled

# label controlplane node
sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label node controlplane new-label="123" --overwrite
# node/controlplane labeled
```

---

- ImagePolicyWebHook
  - Know the end to end steps to create and enable ImagePolicyWebhook.
    - Step 1: Create a Configuration File.
    - Step 2: Create a KubeConfig file.
    - Step 3: Mount Volumes
    - Step 4: Enable Admission Controller.

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
