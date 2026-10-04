# Practices - Admission

[Back](../../README.md)

- [Practices - Admission](#practices---admission)
  - [Admission: PSA \& PSS](#admission-psa--pss)
  - [Admission: `NodeRestriction`](#admission-noderestriction)
  - [Admission: Image Policy Webhook](#admission-image-policy-webhook)
  - [Admission: `ImagePolicyWebhook`](#admission-imagepolicywebhook)
  - [Admission: PSS](#admission-pss)
  - [Admission: ImagePolicyWebhook(killer A)](#admission-imagepolicywebhookkiller-a)
  - [Admission: PSS(killer B)](#admission-psskiller-b)
  - [Task: admission - imagepolicy](#task-admission---imagepolicy)
  - [Task: PSS - Security context](#task-pss---security-context)
  - [Task: PSS - RS](#task-pss---rs)
  - [Task: admission - imagepolicy](#task-admission---imagepolicy-1)
  - [Task: PSS - label](#task-pss---label)
  - [PSS](#pss)
  - [Admission - PSS](#admission---pss)
  - [PSS - label](#pss---label)
  - [PSS - security context](#pss---security-context)

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

---

## Admission: PSS(killer B)

- task:
  - There is a Deployment `container-host-hacker` in Namespace `team-rose` which mounts `/run/containerd` as a hostPath volume on the node where it's running. This means that the Pod can access various data about other containers running on the same node.
  - To prevent this, configure Namespace `team-rose` to `enforce` the `baseline` Pod Security Standard.
  - Once completed, delete the Pod of the Deployment mentioned above.
  - Check the `ReplicaSet events` and write the event/log lines containing the reason why the Pod isn't recreated into `/course/4/logs`.

---

- solution:

```sh
# add label
kubectl label ns team-rose pod-security.kubernetes.io/enforce=baseline
# confirm
k get ns team-rose --show-labels

# remove pod
k -n team-rose delete pod container-host-hacker-dbf989777-wm8fc --force --grace-period 0

# get rs
k -n team-rose get rs
# NAME                              DESIRED   CURRENT   READY   AGE
# container-host-hacker-dbf989777   1         0         0       5m25s

k -n team-rose describe rs container-host-hacker-dbf989777
  # Warning  FailedCreate  78s                replicaset-controller  Error creating: pods "container-host-hacker-dbf989777-x5v5t" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")
  # Warning  FailedCreate  39s (x7 over 77s)  replicaset-controller  (combined from similar events): Error creating: pods "container-host-hacker-dbf989777-64q6p" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")

```

---

## Task: admission - imagepolicy

Task
We need to ensure that when pods are created in this cluster, they cannot use the latest image tag, irrespective of the repository being used.

To achieve this, a simple `Admission Webhook Server` has been developed and deployed. A service called `image-bouncer-webhook` is deployed in the cluster. This Webhook server ensures that the developers of the team cannot use the latest image tag. Use the following specs to integrate it with the cluster using an `ImagePolicyWebhook`:

- Create a new admission configuration file at `/etc/admission-controllers/admission-configuration.yaml`
- The kubeconfig file with the credentials to connect to the webhook server is located at `/root/CKS/ImagePolicy/admission-kubeconfig.yaml`.
  - Note: The `/root/CKS/ImagePolicy/` directory is already mounted on the kube-apiserver at path `/etc/admission-controllers`, so reference that path in reference the admission configuration.
- Ensure that if the latest tag is used, the request must be rejected at all times.
- Enable the Admission Controller.

- Finally, delete the existing pod in the magnum namespace that violates the policy and recreate it, ensuring the same image but using tag `1.27`.

NOTE: If the kube-apiserver becomes unresponsive, this can affect the validation of this exam. In such a case, restore the kube-apiserver using the backup file created at: `/root/backup/kube-apiserver.yaml`. Wait for the API to be available again and proceed.

---

- **solution**

- tricky:
  - volume has been mounted. `/root/CKS/ImagePolicy/` -> `/etc/admission-controllers`
    - config file should be in `/root/CKS/ImagePolicy/`

```sh
vi /root/CKS/ImagePolicy/admission-configuration.yaml

# apiVersion: apiserver.config.k8s.io/v1
# kind: AdmissionConfiguration
# plugins:
# - name: ImagePolicyWebhook
#   configuration:
#     imagePolicy:
#       kubeConfigFile: /etc/admission-controllers/admission-kubeconfig.yaml
#       allowTTL: 0
#       denyTTL: 0
#       retryBackoff: 500
#       defaultAllow: false

vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/admission-controllers/admission-configuration.yaml
# - --enable-admission-plugins=ImagePolicyWebhook

# change pod image
```

---

## Task: PSS - Security context

A deployment named `web-server` is running in the `restricted` namespace.

Identify the reason why the deployment is not in a running state; fix the issue so that it can be in a running state.

Do not change the namespace labels or container image.

---

## Task: PSS - RS

Task
There is a deployment named hacker in the namespace team-red, which mounts /run/containerd as a hostPath volume on the Node where it's running.
This means that the Pod can access various data about other containers running on the same Node.

To prevent this, configure the team-red namespace to enforce the baseline Pod Security Standard. Once completed, delete the Pod from the
deployment mentioned above.

Check the ReplicaSet events and write the event lines containing the reason why the Pod isn't recreated into /opt/course/logs.txt.

Note: You may see multiple identical event lines with the same error. Paste only one of them in the logs.txt file - preferably the last one.

---

- Solution
- skip

---

## Task: admission - imagepolicy

We want to deploy an ImagePolicyWebhook admission controller to secure the deployments in our cluster.

Fix the error in `/etc/kubernetes/pki/admission_configuration.yaml` which will be used by ImagePolicyWebhook

Ensure that the policy is set to implicit deny. If the webhook service is not reachable, the configuration should automatically reject all images.

Enable the plugin on the API server.

The kubeconfig file for the existing imagepolicywebhook resources is located at `/etc/kubernetes/pki/admission_kube_config.yaml`

---

- solution

```sh
vi /etc/kubernetes/pki/admission_configuration.yaml
# apiVersion: apiserver.config.k8s.io/v1
# kind: AdmissionConfiguration
# plugins:
# - name: ImagePolicyWebhook
#   configuration:
#     imagePolicy:
#       kubeConfigFile: /etc/kubernetes/pki/admission_kube_config.yaml
#       allowTTL: 50
#       denyTTL: 50
#       retryBackoff: 500
#       defaultAllow: false

vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/pki/admission_configuration.yaml
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
```

---

## Task: PSS - label

Task
The `financial-apps` namespace contains sensitive financial applications that require strict security controls.

Configure Pod Security Admission to:

- Enforce the restricted policy level on the `financial-apps` namespace
- Use the latest version of the Pod Security Standards
- Add a warning level for the baseline policy to alert on less strict pods
- Label the namespace appropriately for the PSA controller

Verify that the configuration is working by attempting to create a privileged pod and observing the rejection.

---

- solution

```sh
k label ns financial-apps \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite

k get ns financial-apps --show-labels
```

---

## PSS

Task
A deployment named `api-server` is running in the namespace `production`. The deployment pods are failing to start.

Identify the issue causing the pods to fail, and then fix the deployment.

---

- solution

Step-by-Step Troubleshooting

- Step 1: Check Current Deployment Status

```sh
kubectl get deployment api-server -n production
kubectl get pods -n production -l app=api-server
```

Observation: No pods have been created, and the deployment shows 0/2 replicas.

- Step 2: Check Deployment Events and Conditions

```sh
kubectl describe deployment api-server -n production
```

Critical Finding: Deployment events indicate Pod Security violations that are preventing pod creation.

- Step 3: Analyze the Exact Security Violations
  To identify the specific violations, review the deployment YAML:

```sh
kubectl get deployment api-server -n production -o yaml
```

Violations Identified:

- privileged: true
- runAsNonRoot: false
- runAsUser: 0 and runAsGroup: 0 (root user)
- Capabilities added: NET_ADMIN, SYS_TIME
- Missing allowPrivilegeEscalation: false
- Missing seccompProfile

- Step 4: Delete and Recreate the Deployment with Correct Settings
  The easiest approach is to delete the broken deployment and recreate it with the correct security context:

```sh
# Delete the broken deployment
kubectl delete deployment api-server -n production

# Create a new deployment with correct security settings
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: production
  labels:
    app: api-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: nginxinc/nginx-unprivileged:1.25.3-alpine
        ports:
        - containerPort: 8080
        securityContext:
          runAsNonRoot: true
          runAsUser: 101
          privileged: false
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
EOF
```

---

## Admission - PSS

Task
We want to deploy a `PodSecurity admission` controller to enforce security standards across the cluster.

Tasks:

Fix the error in `/etc/kubernetes/pki/podsecurity_configuration.yaml` which will be used by the PodSecurity admission controller:

- Ensure the `restricted` level is **enforced** across all namespaces by default, with `baseline` used for **audit** and **warn** modes, and pin all three modes to the latest policy **version**.

Enable the plugin on the API server by:

- Adding `PodSecurity` to the `--enable-admission-plugins` flag (required when using a custom config file)
- Setting `--admission-control-config-file` to point to the configuration file

The PodSecurity admission controller should reject any pods that don't meet the restricted policy standards.

A copy of the kube-apiserver.yaml is available in /tmp/kube-apiserver-backup.yaml so you can revert if the configuration goes wrong. Ensure that the kube-apiserver is working correctly, as it will be required for grading the exam.

---

- solution

```yaml
# /etc/kubernetes/pki/podsecurity_configuration.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      defaults:
        enforce: "restricted"
        enforce-version: "latest"
        audit: "baseline"
        audit-version: "latest"
        warn: "baseline"
        warn-version: "latest"
      exemptions:
        usernames: []
        runtimeClasses: []
        namespaces: []
```

```sh
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/pki/podsecurity_configuration.yaml
# - --enable-admission-plugins=NodeRestriction,PodSecurity

# debug
crictl ps -a | grep kube-apiserver
journalctl -u kubelet -n 50 --no-pager
```

---

## PSS - label

Task
Configure Pod Security Standards for the `scc-demo` namespace so that non-compliant pods are rejected.

Apply `Pod Security Standards` labels to the namespace with:

- Enforce level: `restricted`
- Enforce version: `latest`
- Audit: `restricted`
- Warn: `restricted`

Once applied, the restricted profile automatically enforces most of the key controls for you, including:

- no privilege escalation
- runAsNonRoot
- no host namespaces
- a seccomp profile
- all capabilities dropped

---

```sh
kubectl label ns scc-demo \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite
```

---

## PSS - security context

Task
Migrate the existing deployment `legacy-app` in the `pss-migration` namespace to comply with the `Pod Security Standards` restricted policy level.

Current Issues:
The deployment has insecure settings that violate the restricted policy:

- privileged: true (must be false)
- runAsUser: 0 (must be non-root)

Required Changes:

- Set `privileged: false`
- Set `runAsNonRoot: true` at container level
- Set `allowPrivilegeEscalation: false`
- Drop all `capabilities (capabilities.drop: ["ALL"])`
- Use `runAsUser: 101 (nginx user)`
  Ensure the deployment maintains functionality on port 8080 after migration.

The deployment uses the nginx-unprivileged image which runs as UID 101 by default.

---

- solution

```yaml
containers:
  - name: <existing-container-name>
    image: <existing-nginx-unprivileged-image>
    ports:
      - containerPort: 8080
    securityContext:
      privileged: false
      runAsNonRoot: true
      runAsUser: 101
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
```

---
