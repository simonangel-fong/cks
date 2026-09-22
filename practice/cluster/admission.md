# Practices - Admission

[Back](../../README.md)

- [Practices - Admission](#practices---admission)
  - [Admission: PSA \& PSS](#admission-psa--pss)
  - [Admission: `NodeRestriction`](#admission-noderestriction)
  - [Admission: Image Policy Webhook](#admission-image-policy-webhook)
  - [Admission: `ImagePolicyWebhook`](#admission-imagepolicywebhook)
  - [Admission: PSS](#admission-pss)
  - [Admission: ImagePolicyWebhook(killer A)](#admission-imagepolicywebhookkiller-a)

---

- Pod Security Standards
  - clear understanding of pod security standards, including how to implement and adjust PSS configurations for pods and deployments

- ImagePolicyWebHook
  - Know the end to end steps to create and enable ImagePolicyWebhook.
    - Step 1: Create a Configuration File.
    - Step 2: Create a KubeConfig file.
    - Step 3: Mount Volumes
    - Step 4: Enable Admission Controller.

api server flag: `--enable-admission-plugins`

## Admission: PSA & PSS

- ref:
  - https://kubernetes.io/docs/concepts/security/pod-security-admission/#pod-security-admission-labels-for-namespaces
  - https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
- task:
  - create ns `prod`
  - enforce `restricted` security standard on ns `prod`
  - confirm security standard

---

- solution:

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

## Admission: `NodeRestriction`

- task:
  - enable `NodeRestriction` admission controller, limiting what a node's kubelet can modify
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

## Admission: Image Policy Webhook

- task:
  - webhook is enabled locally `http://127.0.0.1:8080`, allowing nginx and httpd
  - webhook config path is "/etc/kubernetes/pki/webhook-kubeconfig"
  - enable image policy webhook admission in apiserver
  - config admission
  - confimr

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

## Admission: `ImagePolicyWebhook`

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

---

## Admission: PSS

- task:
  - Implement specific security policies in Namespace `team-sepia`.
  - Configure Pod Security Admission in mode `audit` for level `baseline`
  - Configure Pod Security Admission in mode `warn` for level `restricted`
  - Afterwards create the Pod from `/course/7/bad-pod.yaml` and write any warnings or errors into `/course/7/bad-pod.log`

- setup env:

```yaml
# /course/7/bad-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: team-sepia
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
      securityContext:
        allowPrivilegeEscalation: true # violates 'restricted'
```

---

- solution:

```sh
# Configure Pod Security Admission labels
kubectl label namespace team-sepia \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

# confirm
kubectl get namespace team-sepia --show-labels

# write
kubectl create -f /course/7/bad-pod.yaml 2> /course/7/bad-pod.log

cat /course/7/bad-pod.log
kubectl get pod bad-pod -n team-sepia
```

> ref: https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/#add-labels-to-existing-namespaces-with-kubectl-label

---

## Admission: ImagePolicyWebhook(killer A)

- task:
  - Team White created an `ImagePolicyWebhook` solution at `/course/12/webhook` on cks4024 which needs to be enabled for the cluster. There is an existing and working webhook-backend Service in Namespace `team-white` which will be the `ImagePolicyWebhook` backend.
  - Create an `AdmissionConfiguration` at `/course/12/webhook/admission-config.yaml` which contains the following `ImagePolicyWebhook` configuration in the same file:

  ```yaml
  imagePolicy:
    kubeConfigFile: /etc/kubernetes/webhook/webhook.yaml
    allowTTL: 10
    denyTTL: 10
    retryBackoff: 20
    defaultAllow: true
  ```

  - Configure the apiserver to:
    - Mount `/course/12/webhook` at `/etc/kubernetes/webhook`
    - Use the `AdmissionConfiguration` at path `/etc/kubernetes/webhook/admission-config.yaml`
    - Enable the `ImagePolicyWebhook` admission plugin
  - As a result, the ImagePolicyWebhook backend should **prevent** container images containing `danger-danger` from being used. Any other image should still work.
  - ℹ️ Create a backup of /etc/kubernetes/manifests/kube-apiserver.yaml outside of /etc/kubernetes/manifests so you can revert in case of issues
  - ℹ️ Use sudo -i to become root which may be required for this question

---

- solution:

```sh
sudo -i

cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak

vi /course/12/webhook/admission-config.yaml
# apiVersion: apiserver.config.k8s.io/v1
# kind: AdmissionConfiguration
# plugins:
# - name: ImagePolicyWebhook
#   configuration:
#     imagePolicy:
#       kubeConfigFile: /etc/kubernetes/webhook/webhook.yaml
#       allowTTL: 10
#       denyTTL: 10
#       retryBackoff: 20
#       defaultAllow: true

vi /etc/kubernetes/manifests/kube-apiserver.yaml
# # flags
#     - --admission-control-config-file=/etc/kubernetes/webhook/admission-config.yaml
#     - --enable-admission-plugins=ImagePolicyWebhook,NodeRestriction

#     volumeMounts:
#       - name: webhook
#         mountPath: /etc/kubernetes/webhook
#         readOnly: true
#   # create volume
#   volumes:
#    - name: webhook
#      mountPath: /etc/kubernetes/webhook
#      readOnly: true

# confirm
crictl ps | grep apiserver

# test
k run test --image=danger-danger
kubectl run allowed-test --image=nginx:1-alpine
```
