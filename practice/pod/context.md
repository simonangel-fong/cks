# Practices - Pod Security Context

[Back](../../README.md)

- [Practices - Pod Security Context](#practices---pod-security-context)
  - [Security Context: Non-Root User](#security-context-non-root-user)
  - [Security Context: User id \& Group id](#security-context-user-id--group-id)
  - [Security Context: Least privileges](#security-context-least-privileges)
  - [Security Context: Read only root file system](#security-context-read-only-root-file-system)
  - [Security Context: Make the container immutable](#security-context-make-the-container-immutable)
  - [Security Context: readonlyfile(killer A)](#security-context-readonlyfilekiller-a)
  - [Task: security context](#task-security-context)
  - [Task: seccomp](#task-seccomp)
  - [Task: Security context](#task-security-context-1)
  - [Task: security context - rofs](#task-security-context---rofs)
  - [Task: Security context - capabilities](#task-security-context---capabilities)
  - [Task: Security Context - seccomp](#task-security-context---seccomp)
  - [Security context - rofs](#security-context---rofs)
  - [AppArmor](#apparmor)
  - [Security Context](#security-context)

---

- Security Context
  - Privileged Pods, Capabilities, readOnlyRootFilesystem (immutability)

## Security Context: Non-Root User

- task:
  - create a pod
    - named `web-app`
    - image: `bitnami/nginx`
    - run as non-root user

- solution

```yaml
# vi nonroot.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
    - name: web-app
      image: bitnami/nginx
      securityContext:
        runAsNonRoot: true
```

```sh
k apply -f nonroot.yaml
kubectl get po
# NAME      READY   STATUS    RESTARTS   AGE
# web-app   1/1     Running   0          86s

kubectl exec -it web-app -- id
# uid=1001 gid=0(root) groups=0(root)
```

---

## Security Context: User id & Group id

- task:
  - create po named `user-id`:
    - user id = 2000
    - group id = 2000
    - label: `app: user-id`

- solution:

```yaml
# vi user-id.yaml
apiVersion: v1
kind: Pod
metadata:
  name: user-id
  labels:
    app: user-id
spec:
  securityContext:
    runAsUser: 2000
    runAsGroup: 2000
  containers:
    - name: user-id
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
```

```sh
kubectl apply -f user-id.yaml
kubectl exec -it user-id -- id
# uid=2000 gid=2000 groups=2000
```

---

## Security Context: Least privileges

- task:
  - create a pod named `least-privilege`
    - iamge: busybox
    - user id: 2000
    - group id: 2000
    - non root user: true
    - Escalation: false
    - privileged: false
    - drop all capabilities

- solution:

```yaml
# vi least-permission.yaml
apiVersion: v1
kind: Pod
metadata:
  name: least-privilege
spec:
  containers:
    - name: least-privilege
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1h"]
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        privileged: false
        runAsUser: 2000
        runAsGroup: 2000
        capabilities:
          drop:
            - ALL
```

```sh
k apply -f least-permission.yaml

# test
kubectl exec -it least-privilege -- id
# uid=2000 gid=2000 groups=2000

```

> least privileges: `allowPrivilegeEscalation`, `privileged`, `runAsNonRoot`, dropped `capabilities`

---

## Security Context: Read only root file system

- task:
  - create a pod named `rofs` with image `busybox` command `sleep 1d`
  - root fs should be read-only

---

- solution

```yaml
# vi rofs.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rofs
spec:
  containers:
    - name: rofs
      image: busybox:1.28
      command: ["sh", "-c", "sleep 1d"]
      securityContext:
        readOnlyRootFilesystem: true
```

```sh
k apply -f rofs.yaml

# confirm
k get pod
# NAME   READY   STATUS    RESTARTS   AGE
# rofs   1/1     Running   0          2m7s

kubectl exec -it rofs -- touch /tmp/text.txt
# touch: /tmp/text.txt: Read-only file system
# command terminated with exit code 1
```

---

## Security Context: Make the container immutable

- task:
  - deploy `rofs` in `moon` ns does not work with `readOnlyRootFilesystem`
  - fix it
  - hint: nginx need to write /var/cache/nginx and /var/run

- setup env:

```yaml
# vi nginx-ro.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ro
  namespace: moon
spec:
  selector:
    matchLabels:
      app: nginx-ro
  template:
    metadata:
      labels:
        app: nginx-ro
    spec:
      containers:
        - name: nginx-ro
          image: nginx
          securityContext:
            readOnlyRootFilesystem: true
```

```sh
kubectl apply -f nginx-ro.yaml
kubectl get po -n moon
# NAME                        READY   STATUS   RESTARTS      AGE
# nginx-ro-67f6788fdf-tvnd2   0/1     Error    2 (25s ago)   28s
```

---

- solution:

```yaml
# vi nginx-ro.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ro
  namespace: moon
spec:
  selector:
    matchLabels:
      app: nginx-ro
  template:
    metadata:
      labels:
        app: nginx-ro
    spec:
      containers:
        - name: nginx-ro
          image: nginx
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: cache-volume
              mountPath: /var/cache/nginx
            - name: runtime-volume
              mountPath: /var/run
      volumes:
        - name: cache-volume
          emptyDir: {}
        - name: runtime-volume
          emptyDir: {}
```

```sh
kubectl apply -f nginx-ro.yaml

kubectl get po -n moon
# NAME                       READY   STATUS    RESTARTS   AGE
# nginx-ro-c6b6db6b7-bn56z   1/1     Running   0          9s
```

---

## Security Context: readonlyfile(killer A)

- task:
  - The Deployment `immutable-deployment` in Namespace `team-purple` should run immutable. It's created from file `/course/6/immutable-deployment.yaml`. Even after a successful break-in, it shouldn't be possible for an attacker to modify the filesystem of the running container.
  - Modify the Deployment in a way that no processes inside the container can modify the local filesystem, only the `/tmp` directory should be writable. Don't modify the Docker image.
  - Save the updated YAML under `/course/6/immutable-deployment-new.yaml` and update the running Deployment.

---

- setup env

```yaml
# /course/6/immutable-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: team-purple
  name: immutable-deployment
  labels:
    app: immutable-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: immutable-deployment
  template:
    metadata:
      labels:
        app: immutable-deployment
    spec:
      restartPolicy: Always
      containers:
        - image: busybox:1
          command: ["sh", "-c", "tail -f /dev/null"]
          imagePullPolicy: IfNotPresent
          name: busybox
          resources:
            requests:
              cpu: 20m
              memory: 20Mi
```

---

- solution

```yaml
# vi /course/6/immutable-deployment-new.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: team-purple
  name: immutable-deployment
  labels:
    app: immutable-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: immutable-deployment
  template:
    metadata:
      labels:
        app: immutable-deployment
    spec:
      restartPolicy: Always
      containers:
        - name: busybox
          image: busybox:1
          command: ["sh", "-c", "tail -f /dev/null"]
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: 20m
              memory: 20Mi
          # add
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

```sh
cp /course/6/immutable-deployment.yaml /course/6/immutable-deployment-new.yaml

kubectl apply -f /course/6/immutable-deployment-new.yaml
kubectl rollout status deployment/immutable-deployment -n team-purple

# confirm
kubectl exec -n team-purple deploy/immutable-deployment -- touch /tmp/test
kubectl exec -n team-purple deploy/immutable-deployment -- touch /test
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

## Task: Security context

Task
A pod named `secure-app` in the `security-context` namespace is currently running with excessive privileges. The container is capable of escalating privileges and executing as the root user, which presents a significant security risk.

Please modify the pod configuration to achieve the following objectives:

- Prevent privilege escalation
- Ensure the container operates as a non-root user
- Set the user ID to 101 and the group ID to 101
- Utilize the nginxinc/nginx-unprivileged:alpine image
- Configure the container to listen on port 8080

Ensure that the pod remains capable of serving web content on port 8080. You may need to delete and recreate the pod with the appropriate security context.

---

- solution

```yaml
containers:
  - name: secure-app
    image: nginxinc/nginx-unprivileged:alpine
    ports:
      - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 101
      runAsGroup: 101
```

---

## Task: security context - rofs

Task
A deployment named `data-processor` in the `immutable-apps` namespace is currently at risk of file system attacks due to the use of a writable root filesystem.

The deployment has the following volumes mounted for writable storage:

- /tmp
- /var/log
- /var/cache/nginx
- /var/run

Your task is to:

- Configure the containers to utilize a read-only root filesystem
- Ensure that the application retains the capability to write to the mounted volumes
- Confirm that the nginx web server remains operational

Please modify the deployment as necessary and test the application's functionality.

---

- solution:

```yaml
containers:
  - name: nginx
    image: nginx
    securityContext:
      readOnlyRootFilesystem: true
```

---

## Task: Security context - capabilities

Task
A pod definition file at `/root/CKS/data-processor.yaml` has excessive Linux capabilities that pose a security risk.

Secure the pod by:

- Dropping `ALL` Linux capabilities by default
- Adding back only the `NET_BIND_SERVICE` capability
- Ensuring the pod can still bind to port 8080
- Generating a `kubesec scan` report after fixing the pod

Once done, generate the report again and save it to `/root/CKS/capabilities-report.txt`

---

- solution

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

---

## Task: Security Context - seccomp

Task
A security audit identified that containers in the `secure-runtime` namespace could be vulnerable to process debugging attacks. There is already a pod named `secure-app` running in this namespace.

Your task is to:

Create a custom seccomp profile that:

- Blocks the `ptrace` and `process_vm_readv` syscalls to prevent process debugging
- Allows all other syscalls to maintain application functionality (use `SCMP_ACT_ALLOW` as the default action)
- Uses `SCMP_ACT_ERRNO` action for the blocked syscalls
- Save the profile as `/var/lib/kubelet/seccomp/profiles/block-debug.json`

Configure the existing secure-app pod to use this custom seccomp profile

Ensure the pod remains functional and can still serve nginx content after applying the seccomp profile

Note: You may need to restart or recreate the pod to apply the seccomp profile changes.

---

```sh
# get node
k -n secure-runtime get po secure-app -o wide

mkdir -p /var/lib/kubelet/seccomp/profiles
vim /var/lib/kubelet/seccomp/profiles/block-debug.json
```

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["ptrace", "process_vm_readv"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

```yaml
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-debug.json
```

---

## Security context - rofs

Task
A deployment named `log-aggregator` in the `secure-logging` namespace is currently vulnerable to runtime tampering because its container uses a writable root filesystem. This could allow an attacker to modify application binaries or configuration files if the container is compromised.

The application requires write access only to the following specific directories for its normal operation:

/var/log/application (for application logs)
/tmp (for temporary processing files)
/var/cache (for cached data)
/var/run (for nginx runtime files like PID)
Your objective is to:

Harden the deployment by configuring its container to use a read-only root filesystem
Preserve application functionality by ensuring it can still write to the required directories listed above
Verify the solution by confirming the pod runs successfully and the logging service remains operational
Make the necessary changes to the deployment and validate that the application works correctly under the new security constraints.

---

- solution

```yaml
spec:
  template:
    spec:
      containers:
        - name: <existing-container-name>
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: app-logs
              mountPath: /var/log/application
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /var/cache
            - name: run
              mountPath: /var/run

      volumes:
        - name: app-logs
          emptyDir: {}
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
        - name: run
          emptyDir: {}
```

---

## AppArmor

A deployment named `frontend` in the `apparmor-demo` namespace requires additional security isolation. An `AppArmor` profile has been created at `/etc/apparmor.d/containers/restricted-frontend` with the following security restrictions:

- Prevents the container from writing to /etc/, /bin/, /sbin/, /usr/bin/, and /usr/sbin/ directories
- Allows network access only on TCP and UDP protocols
- Blocks raw socket access
- Allows write access only to /tmp/ directory
- Prevents capability escalation

Your tasks:

- Load the AppArmor profile using `apparmor_parser`
- Configure the deployment to use the `AppArmor` profile using the `securityContext` field (not annotations)

Configuration Details:

- Container name: `web`
- AppArmor profile type: `Localhost`
- LocalhostProfile: `restricted-frontend` (just the profile name, not localhost/restricted-frontend)

Use the modern `securityContext` approach instead of deprecated annotations

---

- solution

```sh
# load apparmor profile
sudo apparmor_parser -r /etc/apparmor.d/containers/restricted-frontend
sudo aa-status | grep restricted-frontend
```

```yaml
containers:
  - name: web
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: restricted-frontend
```

---

## Security Context

Task
Create a pod named `secure-pod` in the `security-context-demo` namespace. This pod requires enhanced security configurations.

Pod Requirements:

- Pod name: secure-pod
- Namespace: security-context-demo
- Label: app: secure-pod
- Image: nginxinc/nginx-unprivileged:alpine
- Container port: 8080

Security Context Requirements:

- Pod-level: Set runAsNonRoot: true, runAsUser: 1001, runAsGroup: 1001
- Container-level: Set allowPrivilegeEscalation: false
- Container-level: Drop all Linux capabilities (capabilities.drop: ["ALL"])

Ensure these security settings are applied correctly while maintaining pod functionality.

---

- solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: security-context-demo
  labels:
    app: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
  containers:
    - name: secure-pod
      image: nginxinc/nginx-unprivileged:alpine
      ports:
        - containerPort: 8080
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
```

---
