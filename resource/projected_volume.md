# CKS: pod - projected volume

[Back](../README.md)

- [CKS: pod - projected volume](#cks-pod---projected-volume)
  - [projected volume](#projected-volume)
  - [Lab: projected volume](#lab-projected-volume)
  - [Lab: mount sa with pv](#lab-mount-sa-with-pv)

---

## projected volume

- ref: https://kubernetes.io/docs/concepts/storage/projected-volumes/

- `Projected volumes`
  - combine several different volume sources **into a single volume mount** in your pod.

- `Secret`, `configMap`, `serviceAccountToken`, `downwardAPI`, `clusterTrustBundle` -> `projected volumes`

---

## Lab: projected volume

```sh
# create secret
kubectl create secret generic firstsecret --from-literal=dbpassword=mypassword123
# secret/firstsecret created

# create cm
kubectl create configmap my-config --from-literal=config-key="This is a config value"
# configmap/my-config created

# create a pod with pv
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
spec:
  containers:
  - name: container-test
    image: busybox:1.37
    command: ["sleep", "3600"]
    volumeMounts:
    - name: all-in-one
      mountPath: "/projected-volume"
      readOnly: true
  volumes:
  - name: all-in-one
    projected:
      sources:
      - secret:
          name: firstsecret
          items:
            - key: dbpassword
              path: my-username
      - configMap:
          name: my-config
          items:
            - key: config-key
              path: my-config
EOF
# pod/volume-test created

# confirm
kubectl exec -it volume-test -- sh
ls /projected-volume
# my-config    my-username
cat /projected-volume/my-config; echo
# This is a config value
cat /projected-volume/my-username; echo
# mypassword123

kubectl delete po volume-test
```

---

## Lab: mount sa with pv

- disable automount sa
- mount sa with projected volume

- https://kubernetes.io/docs/concepts/storage/projected-volumes/#serviceaccounttoken

```yaml
# projected_volume_sa.yaml
---
# ns
apiVersion: v1
kind: Namespace
metadata:
  name: test-ns
---
# sa
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-sa
  namespace: test-ns
automountServiceAccountToken: false # disable auto mount sa
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa-custom
  namespace: test-ns
spec:
  serviceAccountName: custom-sa # sa
  containers:
  - name: container-test
    image: busybox:1.37
    command: ["sleep", "3600"]
    # mount
    volumeMounts:
    - name: token-vol
      mountPath: "/service-account"
      readOnly: true   
  
  volumes:
  # projected volume
  - name: token-vol
    projected:
      sources:
      - serviceAccountToken:
          audience: api
          expirationSeconds: 3600
          path: token
```

```sh
kubectl apply -f projected_volume_sa.yaml
# namespace/test-ns created
# serviceaccount/custom-sa created
# pod/pod-sa-custom created

kubectl exec -n test-ns -it pod-sa-custom -- sh
ls -l /service-account
# lrwxrwxrwx    1 root     root            12 Sep  8 01:07 token -> ..data/token

cat /service-account/token
# eyJhbGciOiJSUzI1NiIsImtpZCI6IkVmQk1iYlZJTks3eTF0N3R2dUJod0xDemxOdWJrQVNjMm9CZkZfWWJKS28ifQ.eyJhdWQiOlsiYXBpIl0sImV4cCI6MTc4ODgzMjc0MSwiaWF0IjoxNzg4ODI5MTQxLCJpc3MiOiJodHRwczovL2t1Ym
# ...
```
