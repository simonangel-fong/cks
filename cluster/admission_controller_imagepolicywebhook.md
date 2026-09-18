# CKS: Cluster - `ImagePolicyWebhook` Admission controller

[Back](../README.md)

- [CKS: Cluster - `ImagePolicyWebhook` Admission controller](#cks-cluster---imagepolicywebhook-admission-controller)
  - [`ImagePolicyWebhook` Admission controllers](#imagepolicywebhook-admission-controllers)
    - [How It Works](#how-it-works)
    - [Sample](#sample)
  - [Lab: `ImagePolicyWebhook` Admission controllers](#lab-imagepolicywebhook-admission-controllers)
    - [Pre-Requisite](#pre-requisite)
    - [Configure Webhook](#configure-webhook)
    - [Configure API Server](#configure-api-server)
    - [Enable Admission Controller Plugins](#enable-admission-controller-plugins)
      - [Test the Setup](#test-the-setup)

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

## Lab: `ImagePolicyWebhook` Admission controllers

- ref: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

### Pre-Requisite

```sh
sudo apt install python3-pip -y
sudo apt install python3-venv -y

mkdir -pv imagepolicywebhook
cd imagepolicywebhook

python3 -m venv .venv
source .venv/bin/activate
pip3 install flask
```

### Configure Webhook

```sh
cd ~/imagepolicywebhook

sudo nano image_policy_webhook.py
```

```py
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
```

```sh
# ##################
# terminal 1: run webhook
# ##################
python3 image_policy_webhook.py

# ##################
# terminal 2: confirm port
# ##################
sudo netstat -ntlp | grep 8080
# tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      271389/python3
```

### Configure API Server

```conf
# sudo nano /etc/kubernetes/pki/webhook-kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: http://192.168.10.150:8080/validate
  name: webhook
contexts:
- context:
    cluster: webhook
  name: webhook-context
current-context: webhook-context
```

```yaml
# sudo nano /etc/kubernetes/pki/admission-config.yaml
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
        defaultAllow: false
```

### Enable Admission Controller Plugins

```sh
sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml
# - --admission-control-config-file=/etc/kubernetes/pki/admission-config.yaml
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
```

#### Test the Setup

```sh
kubectl run nginx-pod --image=nginx
# pod/nginx-pod created

k get po
# NAME        READY   STATUS    RESTARTS   AGE
# nginx-pod   1/1     Running   0          3s

kubectl run redis-pod --image=redis
# Error from server (Forbidden): pods "redis-pod" is forbidden: one or more images rejected by webhook backend
```
