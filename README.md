# CKS

- [Fundamental](./fundamental/fundamental.md)
  - [Certificate](./fundamental/certificate.md)
  - [mTLS](./fundamental/mtls.md)
  - [Utility: `openssl`](./fundamental/openssl.md)
  - [Monolithic vs Microservices](./fundamental/monolithic_microservices.md)

- Cluster
  - Access Control
    - [Authentication](./cluster/authentication.md)
    - [Authorization](./cluster/authorization.md)
      - [RBAC & SA](./cluster/authorization_rbac.md)
    - [Admission Controller](./cluster/admission_controller.md)
      - [ImagePolicyWebhook](./cluster/admission_controller_imagepolicywebhook.md)
  - [Install and upgrade with `kubeadm`](./cluster/kubeadm.md)

- Cluster components
  - etcd
    - [install with systemd](./etcd/etcd_install.md)
    - [mTLS](./etcd/etcd_mtls.md)
    - [debug](./etcd/etcd_debug.md)

  - [`kube-apiserver` security](./apiserver/apiserver.md)
    - [install with systemd](./apiserver/apisever_install.md)
    - [debug](./apiserver/apisever_debug.md)
    - [Encryption at rest](./apiserver/apiserver_encrypt_at_rest.md)
    - [Auditing](./apiserver/apiserver_auditing.md)

  - [`kubelet`](./kubelet/kubelet.md)
  - node
    - [taint](./fundamental/taint.md)

- Api resources
  - [Ingress](./resource/ingress.md)
  - [Network Policies](./resource/np.md)
  - [Secret](./resource/secret.md)

- Workload
  - [Projected Volume](./workload/projected_volume.md)
  - [Privileged Pods](./workload/privileged_pod.md)
  - [Security Context](./workload/security_context.md)
    - [Capabilities](./workload/security_context_capabilities.md)
    - [readOnlyRootFilesystem](./workload/security_context_fs.md)
    - [AppArmor](./workload/security_context_apparmor.md)
  - [ImagePullPolicy](./workload/imagepullpolicy.md)
  - [Pod Security Standard](./workload/pod_security_standard.md)

- Cilium
  - [Install](./cilium/install.md)
  - [Cilium Network Policies](./cilium/netpol.md)
    - [Layer 3](./cilium/netpol_layer3.md)
    - [Layer 4](./cilium/netpol_layer4.md)
    - [DNS rule](./cilium/netpol_dns.md)
    - [Deny Policies](./cilium/netpol_deny.md)
  - [Transparent Encryption](./cilium/encrypt.md)

- Istio
  - [service mesh](./istio/service_mesh.md)
  - [install](./istio/install.md)
  - [Sidecar Injection](./istio/sidecar.md)
  - [mTLS](./istio/mtls.md)
