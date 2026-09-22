# CKS

- [CKS](#cks)
  - [Theory](#theory)
  - [Practices](#practices)
  - [Domains](#domains)
  - [Documentation List](#documentation-list)
  - [Instructions](#instructions)

---

## Theory

- [Environment setup](./setup/setup.md)

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

- Runtime
  - [OCI](./runtime/oci.md)
  - [Sandboxing](./runtime/sandbox.md)

- [Security scan](./scan/scan.md)
  - [Trivy](./scan/trivy.md)
  - [kube-bench](./scan/kube_bench.md)
  - [Static analysis](./scan/static_analysis.md)
  - [Securing Docker Daemon](./scan/docker_daemon.md)
  - [Dockerfile - best practices](./scan/dockerfile_practices.md)
  - [`kubesec`](./scan/kubesec.md)
  - [Bill of Materials](./scan/bom.md)

- monitoring
  - [Falco](./monitor/falco.md)
  - [Falco - Custom rules](./monitor/falco_custom_rule.md)
  - [Sysdig](./monitor/sysdig.md)
  - [Audit](./monitor/audit.md)

---

## Practices

- pod
  - [Image](./practice/pod/image.md)
  - [Daemon & runtime](./practice/pod/daemon.md)
  - [Security Context](./practice/pod/context.md)
  - [AppArmor](./practice/pod/apparmor.md)
  - [RBAC](./practice/pod/rbac.md)
  - [Service Account](./practice/pod/sa.md)
- Cluster
  - [Upgrade](./practice/cluster/upgrade.md)
  - [Binaries & apiserver](./practice/cluster/binary.md)
  - [Node & kubeconfig](./practice/cluster/node.md)
  - [`etcd`](./practice/cluster/etcd.md)
  - [Admission Controller](./practice/cluster/admission.md)
- api resources
  - [Secret](./practice/api/secret.md)
  - [Nework Policy](./practice/api/net_pol.md)
  - [Ingress](./practice/api/ingress.md)
  - [Cilium](./practice/api/cilium.md)
  - [Istio](./practice/api/istio.md)
- Scan
  - [bom](./practice/scan/bom.md)
  - [CIS benchmark](./practice/scan/benchmark.md)
  - [static analysis](./practice/scan/static.md)
- Monitoring
  - [falco](./practice/monitoring/falco.md)
  - [audit](./practice/monitoring/audit.md)

---

[ ] https://github.com/SebastianUA/Certified-Kubernetes-Security-Specialist

[ ] https://github.com/walidshaari/Certified-Kubernetes-Security-Specialist

- youtube question
  - [ ] https://www.youtube.com/watch?v=Jd_j2wruz6E&list=PLpbwBK0ptssx38770vYNwZEuCeGNw54CH
  - [ ] https://www.youtube.com/watch?v=XQPiev_u30k&list=PLyKswBedEWujChLpKK6zFj0S4MOUaxqR3&index=7

---

## Domains

- **Cluster Setup 15%**
  - Use Network security policies to restrict cluster level access
  - Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kubeapi)
  - Properly set up Ingress with TLS
  - Verify platform binaries before deploying
  - Protect node metadata and endpoints

- **Cluster Hardening (15%)**
  - Use Role Based Access Controls to minimize exposure
  - Exercise caution in using **service accounts** e.g. disable defaults, minimize permissions on newly created ones
  - Restrict access to Kubernetes API
  - Upgrade Kubernetes to avoid vulnerabilities
  - Upgrade Kubernetes clusters with kubeadm: from 1.35 -> 1.36

- **System Hardening 10%**
  - Minimize host OS footprint (reduce attack surface)
  - Using least-privilege identity and access management
  - Minimize external access to the network
  - Appropriately use kernel hardening tools such as AppArmor, seccomp

- **Minimize Microservice Vulnerabilities (20%)**
  - Use appropriate pod security standards
  - Manage Kubernetes secrets
  - Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
  - Implement Pod-to-Pod encryption (Cilium, Istio)

- **Supply Chain Security (20%)**
  - Minimize base image footprint
  - Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
  - Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
  - Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)

- **Monitoring, Logging and Runtime Security (20%)**
  - Perform behavioral analytics to detect malicious activities
  - Detect threats within physical infrastructure, apps, networks, data, users and workloads
  - Investigate and identify phases of attack and bad actors within the environment
  - Ensure immutability of containers at runtime
  - Use Kubernetes audit logs to monitor access

---

## Documentation List

- ref: https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed#certified-kubernetes-security-specialist-cks
- During the exam, candidates may:
  - Use the browser within the VM to access the following documentation:
    - `Kubernetes` Documentation: https://kubernetes.io/docs/
      - Note that using the search function on https://kubernetes.io/docs/ is allowed, but you must not open external search results.
    - `Kubernetes Blog`: https://kubernetes.io/blog/
    - `Falco` documentation https://falco.org/docs/
    - `Bom` documentation https://kubernetes-sigs.github.io/bom/cli-reference/
    - `etcd` documentation https://etcd.io/docs/
    - `NGINX Ingress Controller` Documentation https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/
    - `Cilium` Documentation https://docs.cilium.io/en/stable
    - `Istio` Documentation https://istio.io/latest/docs/
  - Task-specific documentation provided in the Quick Reference box. This may include links to the official Kubernetes documentation or other resources that might be needed to solve a task

---

## Instructions

https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks
