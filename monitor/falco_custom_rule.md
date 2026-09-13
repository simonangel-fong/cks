# CKS: Monitoring - Falco custom rules

[Back](../README.md)

- [CKS: Monitoring - Falco custom rules](#cks-monitoring---falco-custom-rules)
  - [Custom Falco Rules](#custom-falco-rules)
    - [Lab: `falco` Custom rule](#lab-falco-custom-rule)
  - [Macros](#macros)
    - [Lab: macro](#lab-macro)
  - [Falco Rule for /dev/mem Acces](#falco-rule-for-devmem-acces)
    - [Lab: create custom for `/dev/mem`](#lab-create-custom-for-devmem)
      - [`/dev/mem`](#devmem)
      - [custom rule](#custom-rule)

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

### Lab: `falco` Custom rule

```yaml
# sudo vi /etc/falco/falco_rules.local.yaml
- rule: Detect curl Execution in Kubernetes Pod
  desc: Detects when the curl utility is executed within a Kubernetes pod.
  condition: >
    spawned_process and container and
    proc.name = "curl"
  output: >
    Suspicious process detected (curl) inside a container_id=%container.id and container_name=%container.name
  priority: WARNING
```

```sh
# restart
sudo systemctl restart falco
# confirm
sudo systemctl status falco --no-page
# ● falco-modern-bpf.service - Falco: Container Native Runtime Security with modern ebpf
#      Loaded: loaded (/usr/lib/systemd/system/falco-modern-bpf.service; enabled; preset: enabled)
#      Active: active (running) since Sun 2026-09-13 04:38:11 EDT; 9min ago
#        Docs: https://falco.org/docs/
#    Main PID: 8731 (falco)
#       Tasks: 19 (limit: 3179)
#      Memory: 99.4M (peak: 470.9M)
#         CPU: 15.223s
#      CGroup: /system.slice/falco-modern-bpf.service

# ##############################
# monitor
# ##############################
sudo journalctl _COMM=falco -p warning -n 1 --no-page
# Sep 13 04:58:29 controlplane falco[14373]: 04:58:29.630761362: Warning Suspicious process detected (curl) inside a container_id=bc94b1b7bf70 and container_name=app container_id=bc94b1b7bf70 container_name=app container_image_repository=docker.io/alpine/curl container_image_tag=latest k8s_pod_name=app k8s_ns_name=default

# ##############################
# Behavior: Deploy app
# ##############################
# run an app
kubectl run app --image=alpine/curl --command sleep 3600

# exec curl in po
k exec -it app -- curl www.google.com
```

---

## Macros

- `Macros`
  - provide a way to **define common sub-portions of rules** in a reusable way.

---

### Lab: macro

```yaml
# sudo vi /etc/falco/falco_rules.local.yaml
- macro: sensitive_files
  condition: fd.name in (/tmp/sensitive.txt)

- rule: Access to Sensitive Files
  desc: Detect any process attempting to read or write sensitive files
  condition: open_read and sensitive_files
  output: "Sensitive file access detected (user=%user.name process=%proc.name file=%fd.name)"
  priority: WARNING
```

```sh
# ##############################
# monitor
# ##############################
sudo systemctl restart falco
sudo systemctl status falco --no-page

sudo journalctl _COMM=falco -p warning -f
# Sep 13 05:15:55 controlplane falco[18540]: 05:15:55.310221859: Warning Sensitive file opened for reading by non-trusted program | file=/tmp/sensitive.txt gparent=sshd ggparent=sshd gggparent=sshd evt_type=openat user=ubuntuadmin user_uid=1000 user_loginuid=1000 process=cat proc_exepath=/usr/bin/cat parent=bash command=cat /tmp/sensitive.txt terminal=34818 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>

# Sep 13 05:17:07 controlplane falco[18540]: 05:17:07.788839429: Warning Sensitive file opened for reading by non-trusted program | file=/tmp/sensitive.txt gparent=sshd ggparent=sshd gggparent=sshd evt_type=openat user=ubuntuadmin user_uid=1000 user_loginuid=1000 process=vi proc_exepath=/usr/bin/vim.basic parent=bash command=vi /tmp/sensitive.txt terminal=34818 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
# Sep 13 05:17:07 controlplane falco[18540]: 05:17:07.788958375: Warning Sensitive file opened for reading by non-trusted program | file=/tmp/sensitive.txt gparent=sshd ggparent=sshd gggparent=sshd evt_type=openat user=ubuntuadmin user_uid=1000 user_loginuid=1000 process=vi proc_exepath=/usr/bin/vim.basic parent=bash command=vi /tmp/sensitive.txt terminal=34818 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>

# ##############################
# Behavior: access fs
# ##############################
touch /tmp/sensitive.txt
# read
cat /tmp/sensitive.txt

# open and write
vi /tmp/sensitive.txt
```

---

## Falco Rule for /dev/mem Acces

- `/dev/mem`:
  - a special device file in Linux that provides access to the system's physical memory.
  - grants access to critical system memory,
    - unauthorized access can lead to Privilege Escalation, Kernel Exploits etc.
- Containers are meant to be isolated and **should not interact directly** with system memory.
- Access to /dev/mem is restricted unless
  - a pod is **privileged**
  - or explicitly **granted** special permissions.

---

### Lab: create custom for `/dev/mem`

#### `/dev/mem`

```sh
# ####################
# access /dev/mem
# ####################
# create common pod
kubectl run common-pod --image=nginx
# pod/common-pod created
kubectl exec -it common-pod -- ls -l /dev/mem
# ls: cannot access '/dev/mem': No such file or directory
# command terminated with exit code 2

# create privilege pod
kubectl run privileged-pod --image=nginx --privileged
# pod/privileged-pod created
kubectl exec -it privileged-pod -- ls -l /dev/mem
# crw-r----- 1 root kmem 1, 1 Sep 13 09:56 /dev/mem
```

---

#### custom rule

```yaml
# sudo vi /etc/falco/falco_rules.local.yaml
- rule: Detect /dev/mem Access from Containers
  desc: Detect processes inside containers attempting to access /dev/mem
  condition: >
    (open_read or open_write) and
    fd.name=/dev/mem and container.id != host
  output: >
    "Container: %container.id and %container.name attempted to access /dev/mem"
  priority: CRITICAL
```

```sh
# #################################
# monitor
# #################################
sudo systemctl restart falco
sudo systemctl status falco --no-page

sudo journalctl _COMM=falco -f
# Sep 13 06:04:26 controlplane falco[31958]: 06:04:26.254012110: Critical "Container: 578e920316b7 and privileged-pod attempted to access /dev/mem" container_id=578e920316b7 container_name=privileged-pod container_image_repository=docker.io/library/nginx container_image_tag=latest k8s_pod_name=privileged-pod k8s_ns_name=default

# #################################
# behavior: access
# #################################
kubectl exec -it privileged-pod -- cat /dev/mem
```
