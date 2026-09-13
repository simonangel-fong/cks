# CKS

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
  - [Bill of Materials](./scan/bom.md)

- monitoring
  - [Falco](./monitor/falco.md)
  - [Falco - Custom rules](./monitor/falco_custom_rule.md)
  - [Sysdig](./monitor/sysdig.md)
  - [Audit](./monitor/audit.md)

---

## Practices

- Exams love Deployment manifests more then Pod manifests.

- documentation list; https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed#certified-kubernetes-security-specialist-cks
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

- CIS Benchmarks
  - It is important to know about configuring Kubernetes components (Control Plane + Worker Node) **based on various CIS Benchmark** related configuration.
  - Be very familiar with `kubeadm` structure and **troubleshooting** pointers.
  - take backup of the config file before modifying
  - e.g.,
    - Set AuthorizationMode for API Server to RBAC,WebHook
    - Disable Anonymous Authentication in Kubelet ( cat /var/lib/kubelet/config.yaml)
    - Disable --auto-tls in etcd

- common troubleshooting
  - kubectl down:
    - check kubelet, systemctl status
    - check kubelet log, journalctl -u kubelet
    - check log files apiserver, tail /var/log/pods/apiserver
    - confirm with document, e.g., flag; space issue: `flag = value`
    - backup config file
    - fix config file
    - confirm, kubectl get

- ImagePolicyWebHook
  - Know the end to end steps to create and enable ImagePolicyWebhook.
    - Step 1: Create a Configuration File.
    - Step 2: Create a KubeConfig file.
    - Step 3: Mount Volumes
    - Step 4: Enable Admission Controller.
- Auditing
  - enable Auditing based on the requirements.
  - common flag
    - `--audit-log-path`: Specifies the file path where the audit log is written.
    - `--audit-log-maxage`: Defines the maximum number of days to retain old audit log files before deletion.
    - `--audit-log-maxbackup`: Sets the maximum number of old audit log files to retain.
    - `--audit-log-maxsize`: Specifies the maximum size (in megabytes) of the audit log file before it gets rotated.
  - sample Question
    - Logs should be stored at /var/log/demo-audit.logs
    - Logs should be retained for the next 30 days.
    - Maximum size before rotation should be 500 MB.
    - Maximum number of 10 audit log files should be made available.

- Docker Security
  - You need to be aware of `Docker Daemon` Security + `Dockerfile` security **best practices**.
  - Example Scenarios:
    1. Analyze the Dockerfile and fix 5 security issues.
    2. Disable Docker Daemon to listen on 2375
       - know the config file, can be systemd, can be json config file
    3. Make Docker Daemon Secure
    4. Remove user from docker group.

- Static Analysis on Kubernetes Manifest
  - should be able to read a given Kubernetes manifest file and fix any security related issues.
    - know the best practices
    - focus on security context

- Network Policies + Cilium Network Policies
  - For Cilium Network Policy:
    - Be aware of `ingressDeny` and `egressDeny` block.
    - Be aware of the `Entities` in Cilium Network Policies.

- Pod Security Standards
  - clear understanding of pod security standards, including how to implement and adjust PSS configurations for pods and deployments

- Security Context
  - Privileged Pods, Capabilities, readOnlyRootFilesystem (immutability)

- Kubernetes Secrets
  - basics of creating Secrets and mounting them to Pods.
  - various type of secrets
    1. Opaque Secrets.
    2. TLS Secrets
    3. Docker config Secrets

- BOM and SBOM
  - You should know on how to create SBOM using `bom` tool based on requirements.
  - Example: Identify Image that has xyz 1.3.2 package and create SBOM for it.

- Kubernetes Cluster Upgrade
  - Learn to upgrade both control plane and worker nodes using kubeadm

- Ingress with TLS
  - Be familiar with the steps required to set up Ingress with TLS.
  - Be familiar with ssl-redirect annotation for HTTP to HTTPS

- Service Account + Projected Volumes
  - Know how to **create** `service accounts` with auto **mounting token** as disabled.
  - Be familiar with mounting volume sources like SA using `Projected Volumes`.

- Falco
  - Be prepared to develop a `Falco rule` according to a given specification.
  - If you encounter issues with **Falco log generation**, verify that `syslog` is enabled with **debug priority**.
  - Alternatively, run `Falco` directly from the **command line**, bypassing `systemd`.

- Istio
  - Enable istio-proxy injection in a namespace
    - `kubectl label namespace target-namespace istio-injection=enabled --overwrite=true`
    - https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/#deploying-an-app
  - Enforce strict mTLS in the namespace.
    - https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/#lock-down-to-mutual-tls-by-namespace

---

https://github.com/techiescamp/cks-certification-guide
https://github.com/SebastianUA/Certified-Kubernetes-Security-Specialist
https://github.com/zealvora/certified-kubernetes-security-specialist
