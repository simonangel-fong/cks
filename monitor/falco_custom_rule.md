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
  - [Falco Rules](#falco-rules)
  - [Rule Syntax](#rule-syntax)
  - [Macros](#macros-1)
  - [Lists](#lists)
  - [Default and Local Rules Files](#default-and-local-rules-files)
  - [Condition Syntax](#condition-syntax)
    - [Operators](#operators)
    - [Transformers](#transformers)
  - [Outputs](#outputs)

---

## Custom Falco Rules

- falco rule path:

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

---

## Falco Rules

- `Falco rules file`:
  - a YAML file containing mainly three types of elements.

| Element  | Description                                                                         |
| -------- | ----------------------------------------------------------------------------------- |
| `Rules`  | **Conditions** under which an **alert** should be generated.                        |
| `Macros` | **Rule condition snippets** that can be re-used inside rules and even other macros. |
| `Lists`  | **Collections of items** that can be included in rules, macros, or other lists.     |

---

## Rule Syntax

| Key                      | Required | Description                                                                                                | Default |
| ------------------------ | -------- | ---------------------------------------------------------------------------------------------------------- | ------- |
| `rule`                   | yes      | A short, unique name for the rule.                                                                         |         |
| `condition`              | yes      | A filtering expression that is applied against events to check whether they match the rule.                |         |
| `desc`                   | yes      | A longer description of what the rule detects.                                                             |         |
| `output`                 | yes      | Specifies the message that should be output if a matching event occurs.                                    |         |
| `priority`               | yes      | A case-insensitive representation of the severity of the event.                                            |         |
| `exceptions`             | no       | A set of exceptions that cause the rule to not generate an alert.                                          |         |
| `enabled`                | no       | If set to false, a rule is neither loaded nor matched against any events.                                  | true    |
| `tags`                   | no       | A list of tags applied to the rule (more on this here).                                                    |         |
| `warn_evttypes`          | no       | If set to false, Falco suppresses warnings related to a rule not having an event type (more on this here). | true    |
| `skip-if-unknown-filter` | no       | If set to true, if a rule conditions contains a filtercheck                                                | false   |
| `source`                 | no       | The event source for which this rule should be evaluated.                                                  | syscall |

---

- `Rules`
  - a YAML object, part of the rules file, whose definition contains at least the following fields:

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

- `condition` field
  - a **Boolean predicate** expressed using the condition syntax.
  - sample:

    ```yaml
    # checks wheather the event happened in a container
    # checks that the process name is bash
    container.id != host and proc.name = bash
    ```

---

- `Output`
  - a string that can use the same fields that conditions can use prepended by % to perform interpolation, akin to printf. For example:
  - sample:
  ```yaml
  Disallowed SSH Connection
  (command=%proc.cmdline connection=%fd.name
  user=%toupper(user.name) user_loginuid=%user.loginuid container_id=%toupper(container.id)
  image=%container.image.repository)
  ```

---

- `Priority`
  - indicates how serious a violation of the rule is.
  - values:
    - `EMERGENCY`
    - `ALERT`
    - `CRITICAL`
    - `ERROR`: If a rule is related to writing state (i.e. filesystem, etc.)
    - `WARNING`: If a rule is related to an unauthorized read of state (i.e. reading sensitive files, etc.),
    - `NOTICE`: If a rule is related to unexpected behavior (spawning an unexpected shell in a container, opening an unexpected network connection, etc.),
    - `INFORMATIONAL`: If a rule is related to behaving against good practices (unexpected privileged containers, containers with sensitive mounts, running interactive commands as root),
    - `DEBUG`

---

## Macros

- `Macros`
  - provide a way to define common sub-portions of rules in a **reusable way**.
- default macros: `rules/falco_rules.yaml` file.

- sample:

```yaml
- macro: container
  condition: (container.id != host)

- macro: spawned_process
  condition: (evt.type in (execve, execveat))
```

---

## Lists

- `Lists`
  - named **collections of items** that you can include in rules, macros, or even other lists.

- Each list node has the following keys:

| Key     | Description                              |
| ------- | ---------------------------------------- |
| `list`  | The unique name for the list (as a slug) |
| `items` | The list of values                       |

- sample

```yaml
- list: shell_binaries
  items: [bash, csh, ksh, sh, tcsh, zsh, dash]

- list: userexec_binaries
  items: [sudo, su]

- list: known_binaries
  items: [shell_binaries, userexec_binaries]

- macro: safe_procs
  condition: proc.name in (known_binaries)
```

---

## Default and Local Rules Files

```
/etc/falco/
├── falco.yaml                  # default configuration file, How Falco operates
├── config.d/                   # Additional configuration, extend or override falco.yaml
├── falco_rules.yaml            # default rules
├── falco_rules.local.yaml      # custom rules and overrides.
└── rules.d/                    # Additional rule files
```

---

## Condition Syntax

- `condition`
  - defines the **filter** that determines which **events are detected** by the rule.
  - a boolean expression that evaluates to true or false for each event.
    - If it evaluates to `true`, the rule triggers and **generates an alert**.

---

### Operators

| Operators | Description                                                                                        |
| --------- | -------------------------------------------------------------------------------------------------- |
| `and`     | Logical AND operator to connect two or more comparisons (ie. evt.type = open and fd.typechar='f'). |
| `or`      | Logical OR operator to connect two or more comparisons (ie. proc.name = bash or proc.name = zsh).  |
| `not`     | Logical NOT operator to negate a comparison (ie. not proc.name = bash).                            |

skip

---

### Transformers

like function

---

## Outputs

- Falco can **send alerts** to one or more output channels:
  - Standard Output
  - A file
  - `Syslog`
  - A spawned program
  - An HTTP/HTTPS endpoint


- configuration:

```yaml
# Standard output
stdout_output:
  enabled: true
# File Output
file_output:
  enabled: true
  keep_alive: false
  filename: ./events.txt
# Syslog Output
syslog_output:
  enabled: true
```
