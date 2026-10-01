# kk lab1

[Back](../README.md)

- [kk lab1](#kk-lab1)
  - [Task: SA - role](#task-sa---role)
  - [Task: secret - volume](#task-secret---volume)
  - [Task: admission - imagepolicy](#task-admission---imagepolicy)
  - [Task: Audit](#task-audit)
  - [Task: RBAC](#task-rbac)
  - [Task: Ingress TLS](#task-ingress-tls)
  - [Task: security context](#task-security-context)
  - [Task: network policy - NS](#task-network-policy---ns)
  - [Task: PSS - Security context](#task-pss---security-context)
  - [Task: SA - projected volume](#task-sa---projected-volume)
  - [Task: bom](#task-bom)
  - [Task: falco - config,custom rule](#task-falco---configcustom-rule)
  - [Task: kube-bench](#task-kube-bench)
  - [Task: seccomp](#task-seccomp)
  - [Task: static analysis](#task-static-analysis)
  - [Task: network policy](#task-network-policy)
  - [Task: Cilium](#task-cilium)
  - [Task: secret token](#task-secret-token)
  - [Task: falco - custom rule](#task-falco---custom-rule)
  - [Task: PSS - RS](#task-pss---rs)
  - [Task: Dockfile](#task-dockfile)
  - [Task: kubesec](#task-kubesec)
  - [Task: istio - sidecar, mtls](#task-istio---sidecar-mtls)
  - [Task: secret - volume](#task-secret---volume-1)
  - [Task: Docker daemon](#task-docker-daemon)
  - [Task: immutable pod](#task-immutable-pod)
  - [Task: Servcie](#task-servcie)
  - [Task: kubelet \& kubeconfig](#task-kubelet--kubeconfig)
  - [Task: admission - imagepolicy](#task-admission---imagepolicy-1)

---

## Task: SA - role

A pod has been created in the `omni` namespace, but it has a few issues that need to be addressed.

- The pod has been created with more permissions than it needs.
- It allows read access to the `/usr/share/nginx/html/internal` directory, making the Internal Site publicly accessible.

To verify this, click the Site button (above the terminal) and add `/internal/` to the end of the URL.

Use the below recommendations to resolve this.

- Use the `AppArmor` profile created at `/etc/apparmor.d/frontend` to restrict access to the internal site.
- The `omni` namespace has several `service accounts`. Apply the principle of least privilege and use the service account with the minimum privileges (excluding the default service account).
- Once the pod is recreated with the correct service account, delete the other unused service accounts in the omni namespace (excluding the default service account).
- Do not create a new service account or use the default service account.

---

- **Solution**

```sh
apparmor_parser -q /etc/apparmor.d/frontend
```

The profile name used by this file is `restricted-frontend` (open the `/etc/apparmor.d/frontend` file to check).

To verify that the profile was successfully loaded, use the aa-status command:

```sh
aa-status | grep restricted-frontend
  #  restricted-frontend
```

The pod should only use the service account called `frontend-default` as it has the least privileges of all the service accounts in the `omni` namespace (excluding default)
The other service accounts, fe and `frontend` have additional permissions (check the `roles` and `rolebindings` associated with these accounts)

Use the below YAML file to re-create the frontend-site pod after deleting the original frontend-site pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: frontend-site
  namespace: omni
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: restricted-frontend
  serviceAccountName: frontend-default #Use the service account with least privileges
  containers:
    - image: nginx:alpine
      name: nginx
      volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: test-volume
  volumes:
    - name: test-volume
      hostPath:
        path: /data/pages
        type: Directory
```

Alternatively, you can also use the edit command to edit the running pod definition:

```sh
kubectl edit pod frontend-site -n omni
```

Then delete the frontend-site pod and apply the file saved in the /tmp folder after editing like the one shown here:

A copy of your changes has been stored to "/tmp/kubectl-edit-3250548530.yaml"

Next, Delete the unused service accounts in the 'omni' namespace.

```sh
kubectl -n omni delete sa frontend
kubectl -n omni delete sa fe
```

---

## Task: secret - volume

A pod has been created in the `orion` namespace. It uses secrets as environment variables.
Extract the decoded secret for the `CONNECTOR_PASSWORD` and place it under `/root/CKS/secrets/CONNECTOR_PASSWORD`.

You are not yet done; instead of using secrets as an environment variable, mount the secret as a read-only volume at the path `/mnt/connector/password`, which the application can then use.

---

- Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-xyz
  namespace: orion
  labels:
    name: app-xyz
spec:
  containers:
    - name: app-xyz
      image: nginx:alpine
      ports:
        - containerPort: 3306
      volumeMounts:
        - name: secret-volume
          mountPath: /mnt/connector/password
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: a-safe-secret
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

## Task: Audit

You need to enable auditing on this cluster. A basic policy file is available at `/etc/kubernetes/cluster-policy.yaml`.

The logs should be stored at `/var/log/cluster-audit.log`. The logs should be retained for 10 days and should not exceed 10MB. A maximum of 3 files should be kept at a time.

After you enable auditing on the cluster, update the basic policy file to track the following:

- Delete activity on secrets in the kube-system namespace at the Metadata level
- Changes to deployments in the default namespace at the Request level
- All other requests at the Metadata level
- Make sure your changes to the policy file are in effect.

Note: A copy of the kube-apiserver.yaml is kept in ~/ so that you can revert if the configuration goes wrong. Make sure kube-apiserver is working fine for the sake of grading the exam.

---

- **Solution**

```yaml
# /etc/kubernetes/cluster-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: Metadata
    verbs: ["delete"]
    resources:
      - group: ""
        resources: ["secrets"]
    namespaces: ["kube-system"]
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "apps"
        resources: ["deployments"]
    namespaces: ["default"]
  - level: Metadata
```

```sh
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --audit-policy-file=/etc/kubernetes/cluster-policy.yaml
# - --audit-log-path=/var/log/cluster-audit.log
# - --audit-log-maxage=10
# - --audit-log-maxsize=10
# - --audit-log-maxbackup=3

# volumeMounts:
# - name: cluster-audit-policy
#   mountPath: /etc/kubernetes/cluster-policy.yaml
#   readOnly: true
# - name: cluster-audit-log
#   mountPath: /var/log/cluster-audit.log


# volumes:
# - name: cluster-audit-policy
#   hostPath:
#     path: /etc/kubernetes/cluster-policy.yaml
#     type: File
# - name: cluster-audit-log
#   hostPath:
#     path: /var/log/cluster-audit.log
#     type: FileOrCreate

kubectl get nodes
kubectl get namespace default
tail -n 5 /var/log/cluster-audit.log
```

---

## Task: RBAC

A developer named martin needs access to work on the `dev-a`, `dev-b`, and `dev-z` namespaces. He should have the ability to carry out any operation on any pod in the `dev-a` and `dev-b` namespaces. However, on the `dev-z` namespace, he should only have the permission to get and list the pods.

The current setup is too permissive and violates the above condition. Use the above requirement and secure martin's access in the cluster. You may re-create objects; however, ensure to use the same names as the ones in currently in effect.

---

- **Solution**

```sh
kubectl auth can-i --list --as=martin -n dev-a
kubectl auth can-i --list --as=martin -n dev-b
kubectl auth can-i --list --as=martin -n dev-z

# corret rolebinding or clusterrolebinding
# dev-a and dev-b: pods, verbs ["*"]
# dev-z: pods, verbs ["get", "list"]
```

> all permission: verbs="\*"

---

## Task: Ingress TLS

A deployment `rocket-server` is exposed using the service of the same name in the `space` namespace.

Create an ingress resource named `rocket-ingress` to load balance the incoming traffic to the workload on path `/`.

Use the hostname `rocket-server.local` in the Ingress rules.

Utilize the TLS certificate stored in a secret named `rocket-tls` in the `space` namespace so that it enables TLS traffic on that ingress resource.

---

- **Solution**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocket-ingress
  namespace: space
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - rocket-server.local
      secretName: rocket-tls
  rules:
    - host: rocket-server.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: rocket-server
                port:
                  number: 80
```

---

## Task: security context

Edit the gamma deployment in the galaxy namespace to ensure that all containers meet the following requirements:

Run as user 1001
Do not allow privilege escalation
Mount their file systems as read-only

---

- **Solution**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gamma
  namespace: galaxy
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx:1.27
          # here
          securityContext:
            runAsUser: 1001
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
```

---

## Task: network policy - NS

Deployment `web-app` is running in the `products` namespace.

Database `product-db` is running in the `database` namespace.

Create a network policy named `allow-traffic-to-products` that allows traffic from `product-db` to the `web-app` workload, as well as all traffic originating from the `payments` namespace.

Utilize the labels applied on the relevant resources.

---

- **Solution:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-traffic-to-products
  namespace: products
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: database
          podSelector:
            matchLabels:
              app: product-db
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: payments
```

---

## Task: PSS - Security context

A deployment named `web-server` is running in the `restricted` namespace.

Identify the reason why the deployment is not in a running state; fix the issue so that it can be in a running state.

Do not change the namespace labels or container image.

---

## Task: SA - projected volume

Create a service account named `bot-sa` in the namespace `automated`. Make sure that this service account does not get automatically mounted to workloads.

A workload named `sweeper` is also in the `automated` namespace. Set the deployment's service account to the newly created service account, and mount the service account token as a projected volume. Do not change any other fields in the deployment.

---

- **Solution**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bot-sa
  namespace: automated
automountServiceAccountToken: false
```

```yaml
# pod spec
serviceAccountName: bot-sa
volumes:
  - name: bot-token
    projected:
      sources:
        - serviceAccountToken:
            path: token
# containers
volumeMounts:
  - name: bot-token
    mountPath: /var/run/secrets/bot
    readOnly: true
```

> remember: `readOnly: true`

---

## Task: bom

A deployment named fruits in the namespace salad has three containers:

apple
banana, and
kiwi
One of these containers has the package curl installed. Identify which container has that package from the running containers, and create an SBOM SPDX for the container's image.

Use the tarball archive of that particular image stored under /root/ImageTarballs directory for generating the SPDX JSON. The archives have names matching their images.

Save the output in ~/bugged-fruit.spdx. Save the container name in ~/bugged-container.txt.

Note: bom as well as all its required dependencies have already been installed.

---

- **Solution**

```sh
kubectl -n salad exec POD -c apple -- which curl
kubectl -n salad exec POD -c banana -- which curl
kubectl -n salad exec POD -c kiwi -- which curl

echo CONTAINER_NAME > ~/bugged-container.txt

bom generate \
  --image-archive /root/ImageTarballs/CONTAINER_NAME-image.tar \
  --format json \
  --output ~/bugged-fruit.spdx
```

---

## Task: falco - config,custom rule

There is suspicious activity in the cluster involving one of the pods running the `httpd:2.4-alpine` image.

Falco generates frequent alerts that start with: `File below a known binary directory opened for writing`.

Identify the rule causing this alert and update it as per the below requirements:

- Set the rule priority to `CRITICAL` (Note: Falco will format this as "Critical" in log output)
- The rule output must be:
  `File below a known binary directory opened for writing (user_id=%user.uid file_updated=%fd.name command=%proc.cmdline)`
- Configure alerts to be logged to: `/opt/security_incidents/alerts.log`.
  Do not update the default rules file directly. Instead, use the falco_rules.local.yaml file to override.

Expected log format:

```txt
<timestamp>: Critical File below a known binary directory opened for writing (user_id=0 file_updated=/bin/sleep command=tar -xmf - -C /bin)
```

Note: After updating the alert rule, it may take up to a minute for the alerts to appear in the new log location.

---

- solution:

Enable file_output in `/etc/falco/falco.yaml` on the controlplane node:

```yaml
file_output:
  enabled: true # important
  keep_alive: false
  filename: /opt/security_incidents/alerts.log
```

Next, add the updated rule under the `/etc/falco/falco_rules.local.yaml` and hot reload the Falco service:

```yaml
- rule: Write below binary dir
  desc: an attempt to write to any file below a set of binary directories
  condition: >
    bin_dir and evt.dir = < and open_write
    and not package_mgmt_procs
    and not exe_running_docker_save
    and not python_running_get_pip
    and not python_running_ms_oms
    and not user_known_write_below_binary_dir_activities
  output: >
    File below a known binary directory opened for writing (user_id=%user.uid file_updated=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [filesystem, mitre_persistence]
```

To perform hot-reload falco use '`kill -1 /SIGHUP`':

```sh
kill -1 $(cat /var/run/falco.pid)
```

Alternatively, you can also restart the falco service by running:

```sh
systemctl restart falco
```

---

## Task: kube-bench

We have identified a few issues with our kubernetes setup and need your help in fixing them.

Fix the following issues on kubelet:

- Kubelet service file permission issues
- Kubelet config.yaml permission issues

Fix the following issues on etcd:

- Incorrect ownership of the etcd directory

Fix the following issues on the controlplane node:

- Incorrect value of the profiling argument for:
  - kube-controller-manager
  - kube-scheduler

Kube-bench is installed, and its config files are available under /opt/kube-bench. Use the cis-1.10 benchmark with the current Kubernetes version.

Note: Only fix issues that have the status FAIL, except issue number 1.2.5. Also, ignore the issues with policies.

---

- **Solution**

```sh
sudo kube-bench run --benchmark cis-1.10 \
  --config-dir /opt/kube-bench --config /opt/kube-bench/config.yaml \
  --targets master,node
```

Kubelet service file: Find the path reported by kube-bench; check it before editing.

```sh
sudo chmod 644 /path/to/kubelet.service
```

Kubelet configuration: CIS 1.10 requires permissions 600 or more restrictive

```sh
sudo chmod 600 /var/lib/kubelet/config.yaml
```

etcd data directory

```sh
sudo chown -R etcd:etcd /var/lib/etcd
```

Profiling

```sh
sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml
# - --profiling=false
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
```

---

## Task: seccomp

Task
Create a new pod named `audit-nginx` in the `default` namespace using the `nginx:alpine` image. Secure the syscalls that this pod can use by using the `audit.json` seccomp profile in the pod's security context.

The `audit.json` file is provided at the `/root/CKS directory`. Move it into the profiles directory inside the default seccomp directory before creating the pod.

---

- **Solution**

```sh
sudo mv /root/CKS/audit.json /var/lib/kubelet/seccomp/profiles/audit.json
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: audit-nginx
  namespace: default
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/audit.json
  containers:
    - name: nginx
      image: nginx:alpine
```

---

## Task: static analysis

The Release Engineering Team has shared some YAML manifests and Dockerfiles with you for review. These files are located under `/opt/course/`.

As a container security expert, your task is to perform a manual static analysis and identify possible security issues related to unwanted credential exposure. Note that running processes as root is not a concern in this task.

Record the filenames containing issues in `/opt/course/security-issues.txt`.

Note: Assume that all referenced files, folders, secrets, and volume mounts are present in the Dockerfiles and YAML manifests. You can ignore any syntax or logic errors.

---

- **Solution**

- Dockerfile: layer
- k8s manifests plaintext

---

## Task: network policy

Task
A pod called redis-backend has been created in the prod-x12cs namespace. It has been exposed as a service of type ClusterIP. The pod listens on TCP port 6379.

Create a network policy called allow-redis-access to lock down access to this pod only for the following:

Any pod in the same namespace with the label backend=prod-x12cs

All pods in the prod-yx13cs namespace

Ensure that traffic is only allowed on TCP port 6379.

All other incoming connections should be blocked.

Use the existing labels when creating the network policy.

---

- **Solution**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis-access
  namespace: prod-x12cs
spec:
  podSelector:
    matchLabels:
      app: redis-backend # replace with the Pod's actual label
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              backend: prod-x12cs
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: prod-yx13cs
      ports:
        - protocol: TCP
          port: 6379
```

---

## Task: Cilium

There is an existing CiliumNetworkPolicy
default-allow in the namespace team-azure, which allows all traffic.

In the namespace team-azure, create a CiliumNetworkPolicy as follows:

Create a Layer 3 policy named p1 that denies outgoing traffic from Pods with the label role=messenger to Pods with the label role=database.

---

- **Solution**

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: p1
  namespace: team-azure
spec:
  endpointSelector:
    matchLabels:
      role: messenger
  egressDeny:
    - toEndpoints:
        - matchLabels:
            role: database
```

---

## Task: secret token

A pod named apps-cluster-dash has been created in the gamma namespace using a service account called cluster-view. This service account has been granted additional permissions as compared to the default service account and can view resources cluster-wide on this Kubernetes cluster. While these permissions are important for the application in this pod to work, the secret token is still mounted on this pod.

Secure the pod in such a way that the secret token is no longer mounted on this pod. You may delete and recreate the pod.

---

- Solution

```yaml
# remove sa token from projected token
volumes:
  - name: vault-token
    projected:
      sources:
        - serviceAccountToken:
            path: vault-token
```

---

## Task: falco - custom rule

Task
A pod in the sahara namespace has generated alerts that a shell was opened inside the container.

To recognize such alerts, set the priority to ALERT and change the format of the output so that it looks like the below:

```
ALERT timestamp of the event without nanoseconds,User ID,the container id,the container image repository
```

Make sure to update the rule such that the changes persist across Falco updates.

- setup

```yaml
# /etc/falco/falco_rules.yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    Shell is opened ...
  priority: ERROR
  tags: [container, shell, mitre_execution]
```

---

- **Solution**

Solution
Add the below rule to `/etc/falco/falco_rules.local.yaml` and restart the falco service to override the current rule.

```yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    %evt.time.s,%user.uid,%container.id,%container.image.repository
  priority: ALERT
  tags: [container, shell, mitre_execution]
```

Use the falco documentation to use the correct sysdig filters in the output.

For example, the evt.time.s filter prints the timestamp for the event without nano seconds. This is clearly described in the falco documentation here - https://falco.org/docs/rules/supported-fields/#evt-field-class

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

## Task: Dockfile

There is a Dockerfile named unsecure.Dockerfile located at /opt/course/image/.

DevSecOps has asked you to improve this image by:

Changing the base image to alpine:3.12
Not installing curl
Updating nginx to use the version constraint >=1.18.0
Running the main process as user myuser
Do not add any new lines to the Dockerfile - only modify the existing ones.

---

- Solution
- skip

---

## Task: kubesec

Task
A pod definition file has been created at /root/CKS/simple-pod.yaml . Use the kubesec tool to generate a report for this pod definition file and fix the major issues so that the subsequent scan passes.

Once done, generate the report again and save it to the file /root/CKS/kubesec-report.txt

---

- **Solution**

Solution
Remove the `SYS_ADMIN` capability from the container for the simple-webapp-1 pod in the POD definition file and re-run the scan.

```sh
kubesec scan /root/CKS/simple-pod.yaml > /root/CKS/kubesec-report.txt
```

The fixed report should PASS with a message like this:

```json
[
  {
    "object": "Pod/simple-webapp-1.default",
    "valid": true,
    "fileName": "simple-pod.yaml",
    "message": "Passed with a score of 0 points",
    "score": 0,
  },
  ...
]
```

---

## Task: istio - sidecar, mtls

Task
The namespace encrypted has two applications, alpha and beta.

Since these applications handle critical communications, enforce strict mTLS using Istio in the encrypted namespace.

Make sure that the workloads have the istio sidecar injected.

Note: istio and istioctl have already been installed for you.

---

- Solution

```sh
kubectl label namespace encrypted istio-injection=enabled --overwrite

kubectl -n encrypted rollout restart deployment alpha beta
kubectl -n encrypted rollout status deployment alpha
kubectl -n encrypted rollout status deployment beta
```

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: encrypted
spec:
  mtls:
    mode: STRICT
```

---

## Task: secret - volume

Task
In the namespace code, create a TLS secret code-secret with the following certificate and key provided:

cert: /root/custom-cert.crt
key: /root/custom-key.key
Attach that secret as a volume named secret-volume in the deployment code-server.

---

- solution:

```sh
kubectl -n code create secret tls code-secret \
  --cert=/root/custom-cert.crt \
  --key=/root/custom-key.key
```

```yaml
volumes:
  - name: secret-volume
    secret:
      secretName: code-secret

volumeMounts:
  - name: secret-volume
    mountPath: /etc/tls
    readOnly: true
```

---

## Task: Docker daemon

Task
You are setting up a new Kubernetes cluster and need to secure Docker as part of the cluster setup.

Ensure that docker runs under the "root" group and that no external TCP connections are allowed to the docker daemon.

Ensure the configuration is persistent across restarts.

---

- **Solution**

Change the ownership of the docker file:

```sh
sudo chown root:root /var/run/docker.sock
```

Then add --group=root to the ExecStart of docker systemd file:

```sh
sudo systemctl edit docker
```

```conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --group=root
```

Then reload the docker daemon:

```sh
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker
```

To remove the TCP external connections, modify the /etc/docker/daemon.json to remove the tcp section so that the file looks like this:

```json
{
  "hosts": ["unix:///var/run/docker.sock"]
}
```

Then restart docker again.

---

## Task: immutable pod

Task
Delete all pods from the alpha namespace that are not immutable.

Note: A pod is considered non-immutable if it uses elevated privileges or can store state inside the container.

---

- Solution

Solution
Pod `solaris` is immutable as it have `readOnlyRootFilesystem: true` so it should not be deleted.

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsUser: 1000
```

Pod `sonata` is running with `privileged: true`. break the concept of immutability and should be deleted.

```yaml
securityContext:
  privileged: true
  readOnlyRootFilesystem: false
```

Pod `triton` doesn't define `readOnlyRootFilesystem: true`. break the concept of immutability and should be deleted.

```yaml
# no securityContext
```

---

## Task: Servcie

Task
You have an existing Kubernetes setup with the following services running:

Namespace:
system-hardening

Pods:
nginx-internal (Accessible internally)
nginx-external (Exposed externally via NodePort
service)

Services:
nginx-internal-service (Exposed as ClusterIP - internal-only)
nginx-external-service (Exposed as NodePort - accessible externally)

Objective:
Your task is to disable or unexpose ports to minimize external access to unnecessary services.

---

- Solution:
- check labels for the pod
  - add labels
- replace NodePort by ClusterIP
  - http + https

---

## Task: kubelet & kubeconfig

Task
Configure the kubelet on the cluster2-controlplane node to disallow anonymous authentication.

The admin `kubeconfig` file for this cluster is located at:
`/root/custom-config/admin.conf`

Additionally, utilize this kubeconfig file to delete the role custom-role in namespace delta.

Ensure that, from the node, the cluster cannot be accessed with kubectl unless the `--kubeconfig=/root/custom-config/admin.conf` flag is explicitly provided.

---

- solution

Solution
First ssh to cluster2-controlplane cluster:

```sh
ssh cluster2-controlplane
```

Then. open the kubelet config file to edit:

```sh
sudo nano /var/lib/kubelet/config.yaml
# authentication.anonymous.enabled to false

```

```yaml
authentication:
  anonymous:
    enabled: false
```

and authorization.mode to Webhook:

```yaml
authorization:
  mode: Webhook
```

Save and exit the file and then restart the kubelet:

```sh
sudo systemctl restart kubelet
```

---

To make the cluster info inaccessible without the kubeconfig flag:

```sh
mv ~/.kube/config ~/.kube/config.bak
unset KUBECONFIG
```

The kubernetes commands should then not work without using `--kubeconfig=/root/custom-config/admin.conf`.

---

Now delete the custom-role using this kubeconfig file:

```sh
kubectl delete role custom-role -n delta --kubeconfig=/root/custom-config/admin.conf
```

---

## Task: admission - imagepolicy

We want to deploy an ImagePolicyWebhook admission controller to secure the deployments in our cluster.

Fix the error in /etc/kubernetes/pki/admission_configuration.yaml which will be used by ImagePolicyWebhook

Ensure that the policy is set to implicit deny. If the webhook service is not reachable, the configuration should automatically reject all images.

Enable the plugin on the API server.

The kubeconfig file for the existing imagepolicywebhook resources is located at /etc/kubernetes/pki/admission_kube_config.yaml

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
