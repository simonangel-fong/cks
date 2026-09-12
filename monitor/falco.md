# CKS: Monitoring - Falco

[Back](../README.md)

- [CKS: Monitoring - Falco](#cks-monitoring---falco)
  - [Falco](#falco)
    - [How Falco Works](#how-falco-works)
  - [Lab: falco on Ubuntu](#lab-falco-on-ubuntu)
    - [Install](#install)
    - [Monitor host event](#monitor-host-event)
  - [Lab: falco on k8s](#lab-falco-on-k8s)
    - [Deploy Falco](#deploy-falco)
    - [Monitor](#monitor)
  - [Custom Falco Rules](#custom-falco-rules)
    - [Sample rules](#sample-rules)
    - [Lab: Custom falco rules](#lab-custom-falco-rules)
      - [Simple rule](#simple-rule)
  - [Macros](#macros)
    - [Lab: Macros](#lab-macros)

---

## Falco

- `Falco`
  - an open-source, cloud-native runtime **security tool** designed to **detect and alert** on anomalous behavior and security threats in Kubernetes clusters in real time.

### How Falco Works

- **Kernel Monitoring**:
  - Falco acts like a security camera or bouncer for your infrastructure by **tapping into the Linux kernel** using `eBPF (Extended Berkeley Packet Filter)` **probes** or **kernel modules** to monitor `system calls (syscalls)`.
- **Context Enrichment**:
  - It enriches raw kernel **events with metadata** from your container runtime and Kubernetes (such as namespace, pod name, and container ID).
- **Rule Engine**:
  - It matches the enriched **event stream** against a set of YAML-based **rules**
  - e.g., detecting a shell spawned inside a container or unexpected file access.
- **Alerting**:
  - `When a rule violation occurs, Falco triggers an alert sent to standard output, files, or external notification systems.

---

## Lab: falco on Ubuntu

### Install

- ref: https://falco.org/docs/getting-started/falco-linux-quickstart/

```sh
# get gpg key
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

# update repo list
sudo bash -c 'cat << EOF > /etc/apt/sources.list.d/falcosecurity.list
deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main
EOF'

sudo apt-get update -y

sudo apt install -y dkms make linux-headers-$(uname -r)
sudo apt-get install -y dialog

sudo apt-get install -y falco
# 2
# 2

sudo systemctl status falco-modern-bpf.service
# ● falco-modern-bpf.service - Falco: Container Native Runtime Security with modern ebpf
#      Loaded: loaded (/usr/lib/systemd/system/falco-modern-bpf.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-12 00:52:40 EDT; 22s ago
#        Docs: https://falco.org/docs/
#    Main PID: 8958 (falco)
#       Tasks: 17 (limit: 4543)
#      Memory: 84.8M (peak: 101.3M)
#         CPU: 3.237s
#      CGroup: /system.slice/falco-modern-bpf.service
#              └─8958 /usr/bin/falco -o engine.kind=modern_ebpf

# Sep 12 00:52:41 controlplane falco[8958]: Loading rules from:
# Sep 12 00:52:41 controlplane falco[8958]:    /etc/falco/falco_rules.yaml | schema validation: ok
# Sep 12 00:52:41 controlplane falco[8958]:    /etc/falco/falco_rules.local.yaml | schema validation: none
# Sep 12 00:52:41 controlplane falco[8958]: The chosen syscall buffer dimension is: 8388608 bytes (8 MBs)
# Sep 12 00:52:41 controlplane falco[8958]: Starting health webserver with threadiness 4, listening on 0.0.0.0:8765
# Sep 12 00:52:41 controlplane falco[8958]: Loaded event sources: syscall
# Sep 12 00:52:41 controlplane falco[8958]: Enabled event sources: syscall
# Sep 12 00:52:41 controlplane falco[8958]: Opening 'syscall' source with modern BPF probe.
# Sep 12 00:52:41 controlplane falco[8958]: One ring buffer every '2' CPUs.
# Sep 12 00:52:41 controlplane falco[8958]: [libs]: Trying to open the right engine!

sudo systemctl status falco
# ● falco-modern-bpf.service - Falco: Container Native Runtime Security with modern ebpf
#      Loaded: loaded (/usr/lib/systemd/system/falco-modern-bpf.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-12 00:52:40 EDT; 32s ago
#        Docs: https://falco.org/docs/
#    Main PID: 8958 (falco)
#       Tasks: 17 (limit: 4543)
#      Memory: 84.8M (peak: 101.3M)
#         CPU: 3.512s
#      CGroup: /system.slice/falco-modern-bpf.service
#              └─8958 /usr/bin/falco -o engine.kind=modern_ebpf

# Sep 12 00:52:41 controlplane falco[8958]: Loading rules from:
# Sep 12 00:52:41 controlplane falco[8958]:    /etc/falco/falco_rules.yaml | schema validation: ok
# Sep 12 00:52:41 controlplane falco[8958]:    /etc/falco/falco_rules.local.yaml | schema validation: none
# Sep 12 00:52:41 controlplane falco[8958]: The chosen syscall buffer dimension is: 8388608 bytes (8 MBs)
# Sep 12 00:52:41 controlplane falco[8958]: Starting health webserver with threadiness 4, listening on 0.0.0.0:8765
# Sep 12 00:52:41 controlplane falco[8958]: Loaded event sources: syscall
# Sep 12 00:52:41 controlplane falco[8958]: Enabled event sources: syscall
# Sep 12 00:52:41 controlplane falco[8958]: Opening 'syscall' source with modern BPF probe.
# Sep 12 00:52:41 controlplane falco[8958]: One ring buffer every '2' CPUs.
# Sep 12 00:52:41 controlplane falco[8958]: [libs]: Trying to open the right engine!


# confirm
falco --version
# Sat Sep 12 00:53:50 2026: Falco version: 0.44.1 (x86_64)
# Sat Sep 12 00:53:50 2026: Falco initialized with configuration files:
# Sat Sep 12 00:53:50 2026:    /etc/falco/config.d/engine-kind-falcoctl.yaml | schema validation: ok
# Sat Sep 12 00:53:50 2026:    /etc/falco/config.d/falco.container_plugin.yaml | schema validation: ok
# Sat Sep 12 00:53:50 2026:    /etc/falco/falco.yaml | schema validation: ok
# Sat Sep 12 00:53:50 2026: System info: Linux version 6.14.0-37-generic (buildd@lcy02-amd64-031) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #37~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Nov 20 10:25:38 UTC 2
# Falco version: 0.44.1
# Libs version:  0.25.4
# Plugin API:    3.12.0
# Engine:        0.62.0
# Driver:
#   API version:    10.0.0
#   Schema version: 4.3.0
#   Default driver: 10.2.0+driver

falco -L
# ...
# Rule                                               Description
# ----                                               -----------
# Directory traversal monitored file read            Web applications can be vulnerable to directory traversal
#                                                    attacks that allow accessing files outside of the web
#                                                    app's root directory (e.g. Arbitrary File Read bugs).
#                                                    System directories like /etc are typically accessed via
#                                                    absolute paths. Access patterns outside of this (here path
#                                                    traversal) can be regarded as suspicious. This rule
#                                                    includes failed file open attempts.

# Read sensitive file trusted after startup          An attempt to read any sensitive file (e.g. files
#                                                    containing user/password/authentication information) by a
#                                                    trusted program after startup. Trusted programs might read
#                                                    these files at startup to load initial state, but not
#                                                    afterwards. Can be customized as needed. In modern
#                                                    containerized cloud infrastructures, accessing traditional
#                                                    Linux sensitive files might be less relevant, yet it
#                                                    remains valuable for baseline detections. While we provide
#                                                    additional rules for SSH or cloud vendor-specific
#                                                    credentials, you can significantly enhance your security
# ...
```

### Monitor host event

```sh
# Generate a suspicious event
sudo cat /etc/shadow > /dev/null

# monitor terminal
sudo journalctl _COMM=falco -p warning -f
# Sep 12 00:57:56 controlplane falco[8958]: 00:57:56.553092549: Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow gparent=sudo ggparent=bash gggparent=sshd evt_type=openat user=root user_uid=0 user_loginuid=1000 process=cat proc_exepath=/usr/bin/cat parent=sudo command=cat /etc/shadow terminal=34819 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>

# confirm in log
sudo grep Sensitive /var/log/syslog
# 2026-09-12T00:57:56.575708-04:00 controlplane falco: 00:57:56.553092549: Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow gparent=sudo ggparent=bash gggparent=sshd evt_type=openat user=root user_uid=0 user_loginuid=1000 process=cat proc_exepath=/usr/bin/cat parent=sudo command=cat /etc/shadow terminal=34819 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>

```

---

## Lab: falco on k8s

- ref: https://falco.org/docs/getting-started/falco-kubernetes-quickstart/

### Deploy Falco

```sh
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update falcosecurity
# Hang tight while we grab the latest from your chart repositories...
# ...Successfully got an update from the "falcosecurity" chart repository
# Update Complete. ⎈Happy Helming!⎈

helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco
# NAME: falco
# LAST DEPLOYED: Sat Sep 12 01:11:52 2026
# NAMESPACE: falco
# STATUS: deployed
# REVISION: 1
# TEST SUITE: None
# NOTES:
# Falco agents are spinning up on each node in your cluster. After a few
# seconds, they are going to start monitoring your containers looking for
# security issues.

# TIP:
# You can easily forward Falco events to Slack, Kafka, AWS Lambda and more with falcosidekick.
# Full list of outputs: https://github.com/falcosecurity/charts/tree/master/charts/falcosidekick.
# You can enable its deployment with `--set falcosidekick.enabled=true` or in your values.yaml.
# See: https://github.com/falcosecurity/charts/blob/master/charts/falcosidekick/values.yaml for configuration values.

# confirm
kubectl get pods -n falco
# NAME          READY   STATUS    RESTARTS   AGE
# falco-qj7x2   2/2     Running   0          93s
```

### Monitor

```sh
# create a deploy
kubectl create deployment nginx --image=nginx
# deployment.apps/nginx created

# generat event
kubectl exec -it $(kubectl get pods --selector=app=nginx -o name) -- cat /etc/shadow
# root:*:20689:0:99999:7:::
# daemon:*:20689:0:99999:7:::
# bin:*:20689:0:99999:7:::
# sys:*:20689:0:99999:7:::
# sync:*:20689:0:99999:7:::
# games:*:20689:0:99999:7:::
# man:*:20689:0:99999:7:::
# lp:*:20689:0:99999:7:::
# mail:*:20689:0:99999:7:::
# news:*:20689:0:99999:7:::
# uucp:*:20689:0:99999:7:::
# proxy:*:20689:0:99999:7:::
# www-data:*:20689:0:99999:7:::
# backup:*:20689:0:99999:7:::
# list:*:20689:0:99999:7:::
# irc:*:20689:0:99999:7:::
# _apt:*:20689:0:99999:7:::
# nobody:*:20689:0:99999:7:::
# nginx:!:20698::::::

# confirm event
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco | grep Warning
# 05:38:15.494311782: Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow gparent=systemd ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=-1 process=cat proc_exepath=/usr/bin/cat parent=containerd-shim command=cat /etc/shadow terminal=34816 container_id=d29c1069d349 container_name=nginx container_image_repository=docker.io/library/nginx container_image_tag=latest k8s_pod_name=nginx-5869d7778c-zptr2 k8s_ns_name=default

```

---

## Custom Falco Rules

- falco rule path:

```
/etc/falco/
├── falco.yaml                  # configuration file, How Falco operates
├── config.d/                   # Additional configuration, extend or override falco.yaml
├── falco_rules.yaml            # default detection rules
├── falco_rules.local.yaml      # custom rules and overrides.
└── rules.d/                    # Additional rule files
```

- required keys

| Key       | Description                                                                                        |
| --------- | -------------------------------------------------------------------------------------------------- |
| rule      | unique name for the rule.                                                                          |
| desc      | A human-readable description of what the rule does, explaining the security threat being detected. |
| condition | A logical expression that defines when the rule should trigger an alert.                           |
| output    | The alert message that is generated when the rule condition is met                                 |
| priority  | The severity level of the rule                                                                     |

- priority values:
  - `emergency`, `alert`, `critical`, `error`, `warning`, `notice`, `informational`, `debug`.

---

### Sample rules

```yaml
- rule: Detect curl Execution in Kubernetes Pod
  desc: Detects when the curl utility is executed within a Kubernetes pod.
  condition: >
    spawned_process and container and
    proc.name = "curl"
  output: >
    Suspicious process detected (curl) inside a Kubernetes pod.
  priority: WARNING
```

- sample:

```yaml
- rule: shell_in_container
  desc: notice shell activity within a container
  condition: >
    (evt.type in (execve, execveat)) and
    container.id != host and
    (proc.name = bash or
     proc.name = ksh)
  output: >
    shell in a container |
    user=%user.name container_id=%container.id container_name=%container.name
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline
  priority: WARNING
```

---

### Lab: Custom falco rules

#### Simple rule

```yaml
# sudo nano ~/cks/falco/falco_custom_rules_cm.yaml
customRules:
  custom-rules.yaml: |-
    - rule: Write below etc
      desc: An attempt to write to /etc directory
      condition: >
        (evt.type in (open,openat,openat2) and evt.is_open_write=true and fd.typechar='f' and fd.num>=0)
        and fd.name startswith /etc
      output: "File below /etc opened for writing | file=%fd.name pcmdline=%proc.pcmdline gparent=%proc.aname[2] ggparent=%proc.aname[3] gggparent=%proc.aname[4] evt_type=%evt.type user=%user.name user_uid=%user.uid user_loginuid=%user.loginuid process=%proc.name proc_exepath=%proc.exepath parent=%proc.pname command=%proc.cmdline terminal=%proc.tty"
      priority: WARNING
      tags: [filesystem, mitre_persistence]

```

```sh
# upgrade falco
helm upgrade --namespace falco falco falcosecurity/falco --set tty=true -f ~/cks/falco/falco_custom_rules_cm.yaml


kubectl run nginx-pod --image=nginx

kubectl exec -it nginx-pod -- curl google.com
# <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
# <TITLE>301 Moved</TITLE></HEAD><BODY>
# <H1>301 Moved</H1>
# The document has moved
# <A HREF="http://www.google.com/">here</A>.
# </BODY></HTML>

# specify process name falco; priority=warning
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco | grep Warning
sudo journalctl _COMM=falco -p warning
```

---

## Macros

- `Macros`
  - provide a way to **define common sub-portions of rules** in a reusable way.

---

### Lab: Macros

```sh

```
