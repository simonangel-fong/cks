# CKS: Pod security context - readOnlyRootFilesystem

[back](../README.md)

- [CKS: Pod security context - readOnlyRootFilesystem](#cks-pod-security-context---readonlyrootfilesystem)
  - [readOnlyRootFilesystem](#readonlyrootfilesystem)
    - [Lab: `readOnlyRootFilesystem` demo](#lab-readonlyrootfilesystem-demo)
    - [Lab: `readOnlyRootFilesystem` + `emptyDir`](#lab-readonlyrootfilesystem--emptydir)
    - [Lab: `readOnlyRootFilesystem` + `Nginx` demo](#lab-readonlyrootfilesystem--nginx-demo)

---

## readOnlyRootFilesystem

- `readOnlyRootFilesystem`
  - mounts the **container's root** filesystem as **read-only**.
  - can mitigate many common attack vectors by preventing **unauthorized changes** to critical files within the container.

- Common use cases
  - containers where the application does **not need to modify** the root filesystem at runtime.
    - e.g., applications that rely on _external volumes_ for persistent or _temporary data storage_.
    - If your application **requires writable areas** (like /tmp for temporary data), you can explicitly mount these volumes with write permissions while keeping the rest of the filesystem read-only.

- Not use case
  - Some applications are designed to **write logs, cache data, or manage runtime configurations** on the root filesystem.
    - In such cases, forcing the root filesystem to be read-only may break functionality.

- Exception
  - For temporary file storage within your application, an `emptyDir` volume mounted to a location like `/tmp` provides can be a suitable solution

---

### Lab: `readOnlyRootFilesystem` demo

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
  - name: demo
    image: busybox:1.37
    command: [ "sleep", "1h" ]
    securityContext:
      readOnlyRootFilesystem: true
EOF
# pod/readonly-pod created

kubectl exec -it readonly-pod -- sh
touch test.txt
# touch: test.txt: Read-only file system

touch /tmp/test.txt
# touch: /tmp/test.txt: Read-only file systems

# clean up
kubectl delete pod readonly-pod
```

---

### Lab: `readOnlyRootFilesystem` + `emptyDir`

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod-emptydir
spec:
  containers:
    - name: my-container
      image: busybox:1.37
      command: [ "sleep", "1h" ]
      securityContext:
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp-storage
          mountPath: /tmp
  volumes:
    - name: tmp-storage
      emptyDir: {}
EOF
# pod/readonly-pod-emptydir created

kubectl exec -it readonly-pod-emptydir -- sh
touch test.txt
# touch: test.txt: Read-only file system

touch /tmp/test.txt
# confirm
ls -l /tmp/test.txt
# -rw-r--r--    1 root     root             0 Sep 10 09:14 /tmp/test.txt

# clean up
kubectl delete pod readonly-pod-emptydir
```

---

### Lab: `readOnlyRootFilesystem` + `Nginx` demo

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ro
spec:
  containers:
    - name: my-container
      image: nginx
      securityContext:
        readOnlyRootFilesystem: true
EOF
# pod/nginx-ro created

kubectl get po
# NAME       READY   STATUS             RESTARTS     AGE
# nginx-ro   0/1     CrashLoopBackOff   1 (6s ago)   20s

kubectl logs nginx-ro
# /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
# /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
# /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
# 10-listen-on-ipv6-by-default.sh: info: can not modify /etc/nginx/conf.d/default.conf (read-only file system?)
# /docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
# /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
# /docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
# /docker-entrypoint.sh: Configuration complete; ready for start up
# 2026/09/10 09:17:14 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
# nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
```
