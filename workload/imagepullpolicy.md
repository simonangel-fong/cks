# CKS: Pod - ImagePullPolicy

[Back](../README.md)

- [CKS: Pod - ImagePullPolicy](#cks-pod---imagepullpolicy)
  - [ImagePullPolicy](#imagepullpolicy)
    - [Imperative](#imperative)
    - [Declarative](#declarative)
    - [Best practices](#best-practices)
  - [Admission controller: `AlwaysPullImages`](#admission-controller-alwayspullimages)
    - [Lab: `AlwaysPullImages` Admission controller](#lab-alwayspullimages-admission-controller)

---

## ImagePullPolicy

- `kubelet` component interacts with the `runtime` (docker, containerd) to **pull the container image** from registry.
  - list local images:
    - docker runtime: `docker images`
    - containerd runtime: `crictl images`

- `ImagePullPolicy`:
  - tells Kubernetes when to pull an image from a registry
    - `Always`: Pulls the latest image from container registry.
    - `IfNotPresent`: Pulls the image **only if it isn’t already** present on the node.
    - `Never`: Never pull the image. Instead, it assumes the image is already available on the node. Otherwise, it issues error.

      ```sh
      kubectl run never --image=redis --image-pull-policy=Never
      # pod/never created

      kubectl get po never
      # NAME    READY   STATUS              RESTARTS   AGE
      # never   0/1     ErrImageNeverPull   0          32s

      kubectl describe po never
      # Warning  ErrImageNeverPull  10s (x7 over 59s)  kubelet            Container image "redis" is not present with pull policy of Never
      # Warning  Failed             10s (x7 over 59s)  kubelet            Error: ErrImageNeverPull
      ```

- Every time the `kubelet` **launches** a container, the `kubelet` **queries** the container `image registry` to resolve the name to an image digest.
  - If the `kubelet` has a container image with that exact digest **cached locally**, the `kubelet` uses its cached image;
  - otherwise, the kubelet pulls the image with the resolved digest, and uses that image to launch the container.

- **Important**:
  - the event `Successfully pulled image` does not mean pulling from registry, can be get image form local cache.

---

### Imperative

```sh
kubectl run pod-always --image=nginx --image-pull-policy=Always
# pod/pod-always created
kubectl run pod-if-not-present --image=nginx --image-pull-policy=IfNotPresent
# pod/pod-if-not-present created
kubectl run pod-never --image=nginx --image-pull-policy=Never
# pod/pod-never created

# confirm pulling
kubectl describe pod pod-always
# Events:
#   Type    Reason     Age    From               Message
#   ----    ------     ----   ----               -------
#   Normal  Pulling    89s   kubelet            Pulling image "nginx"
#   Normal  Pulled     87s   kubelet            Successfully pulled image "nginx" in 1.628s (1.654s including waiting). Image size: 66343926 bytes.

kubectl describe pod pod-if-not-present
# Events:
#   Type    Reason     Age    From               Message
#   ----    ------     ----   ----               -------
#   Normal  Pulled     2m17s  kubelet            Container image "nginx" already present on machine

kubectl describe pod pod-never
# Events:
#   Type    Reason     Age    From               Message
#   ----    ------     ----   ----               -------
#   Normal  Pulled     3m14s  kubelet            Container image "nginx" already present on machine
```

---

### Declarative

```yaml
kind: Pod
spec:
  containers:
    - name: my-container
      imagePullPolicy: Always
```

---

### Best practices

- You should **avoid** using the `:latest` tag when deploying containers in production as it is harder to track which version of the image is running and more difficult to roll back properly.
- Instead, specify a **meaningful tag** such as `v1.42.0` and/or a **digest**.

---

## Admission controller: `AlwaysPullImages`

- problem
  - If a **sensitive container image** is downloaded to a worker node using **valid credentials**, an unauthorized person can later create a new Pod using that same image with `imagePullPolicy` set to `'Never'`, **bypassing** the need for authentication credentials.

- `AlwaysPullImages` admission controller
  - modifies every new Pod to **force** the `image pull policy` to **Always**
  - assure that private images can only be used by **those who have the credentials** to pull them.
    - Without this admission controller, once an image has been pulled to a node, any pod from **any user can use** it by knowing the image's name

---

### Lab: `AlwaysPullImages` Admission controller

```sh
# ##############################
# before enable
# ##############################
kubectl run before-ac-alwayspullimage --image=nginx --image-pull-policy=Never
# pod/before-ac-alwayspullimage created

kubectl get po before-ac-alwayspullimage -o yaml | grep -i imagePullPolicy
    # imagePullPolicy: Never


# ##############################
# enable
# ##############################
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# update:
#     - --enable-admission-plugins=NodeRestriction,AlwaysPullImages

# ##############################
# after enable
# ##############################
kubectl run after-ac-alwayspullimage --image=nginx --image-pull-policy=Never
# pod/after-ac-alwayspullimage created

# confirm: manifest in cluster get mutated.
kubectl get po after-ac-alwayspullimage -o yaml | grep -i imagePullPolicy
    # imagePullPolicy: Always
```
