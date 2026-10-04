# Practices - falco

[Back](../../README.md)

- [Practices - falco](#practices---falco)
  - [Shortcut](#shortcut)
    - [Falco condition types](#falco-condition-types)
  - [falco(killer A)](#falcokiller-a)
  - [falco(killer B)](#falcokiller-b)
  - [falco: syscall(killer B)](#falco-syscallkiller-b)
  - [falco: pod access /dev/mem](#falco-pod-access-devmem)
  - [Task: falco - config,custom rule](#task-falco---configcustom-rule)
  - [Task: falco - custom rule](#task-falco---custom-rule)
  - [Task: falco - find pod](#task-falco---find-pod)
  - [falco - /etc/shadow](#falco---etcshadow)

---

## Shortcut

- Falco
  - Be prepared to develop a `Falco rule` according to a given specification.
  - If you encounter issues with **Falco log generation**, verify that `syslog` is enabled with **debug priority**.
  - Alternatively, run `Falco` directly from the **command line**, bypassing `systemd`.

| CMD                      | DESC                                                 |
| ------------------------ | ---------------------------------------------------- |
| `falco -U`               | unbuffered and immediately output                    |
| `falco -U \| grep httpd` | keep lines containing “httpd”                        |
| `falco -M <num_seconds>` | Stop Falco execution after <num_seconds> are passed. |
| `falco -r <rules_file>`  | Specify rules file                                   |
| `falco -V <rules_file>`  | validate rules file                                  |

---

### Falco condition types

- common field:
  - network:
    - `fd.rip`
    - `fd.rport`
    - `fd.lip`
    - `fd.lport`
    - `fd.name`
  - file:
    - `evt.type`
    - `fd.name`
    - `fd.directory`
    - `fd.filename`
  - user:
    - `user.uid`
    - `user.name`
  - event:
    - `evt.type`
    - `evt.time`
    - `evt.time.s`
  - process
    - `proc.name`
    - `proc.cmdline`

---

- files

```yaml
condition: >
  evt.type in (open, openat, openat2)
  and fd.name = "/dev/mem"

condition: >
   evt.type in (open, openat, openat2)
   and evt.is_open_write=true
   and fd.name startswith "/path"
```

- Spawn/execute a process

```yaml
# execute curl
condition: >
  evt.type in (execve, execveat)
  and proc.name = curl

# execute with args
condition: >
  evt.type in (execve, execveat)
  and proc.cmdline contains "chmod 777"

# parent process
condition: >
  evt.type in (execve, execveat)
  and proc.pname = nginx
  and proc.name = bash

# user id
condition: >
  evt.type in (execve, execveat)
  and user.name = root
  and proc.name = curl

```

- Spawn process inside a container

```yaml
# start bash in con
condition: >
  evt.type in (execve, execveat)
  and container.id != host
  and proc.name = bash

# curl in con
condition: >
  evt.type in (execve, execveat)
  and container.id != host
  and proc.name = curl
  and proc.cmdline contains "169.254.169.254"

# privileged
condition: >
  evt.type in (open, openat, openat2)
  and container.id != host
  and container.privileged = true


```

---

## falco(killer A)

- task:
  - Add two new Falco rules to `/etc/falco/falco_rules.local.yaml`:
    - Named **Custom Rule 1** with priority `WARNING`. It should find all containers that access files on the host whose full path starts with /etc/kubernetes. It should output logs as:

    ```yaml
    custom_rule_1 file={{FILEPATH}} container={{CONTAINER_ID}}
    ```

    - Named **Custom Rule 2** with priority `INFO`. It should find all processes that perform `kill` syscalls. It should output logs as:

    ```yaml
    custom_rule_2 event_signal=%evt.arg.sig event_pid=%evt.arg.pid container={{CONTAINER_ID}}
    ```

  - Only create the new rules without additional macros or lists.
  - Run Falco with your implemented rules for at least 30 seconds and write the produced logs into `/course/16/logs`.

---

- solution:

```sh
sudo -i
vi /etc/falco/falco_rules.local.yaml
```

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Custom Rule 1
  desc: Custom Rule 1
  condition: container and evt.type in (open, openat) and fd.name startswith /etc/kubernetes
  output: custom_rule_1 file=%fd.name container=%container.id
  priority: WARNING

- rule: Custom Rule 2
  desc: Custom Rule 2
  condition: syscall.type = kill
  output: custom_rule_2 event_signal=%evt.arg.sig event_pid=%evt.arg.pid container=%container.id
  priority: INFO
```

```sh
# write log
falco -M 30 > /course/16/logs 2>&1
```

---

## falco(killer B)

- task:
  - Falco is installed on worker node `node1`. Connect using `ssh node1`. There is a file `/etc/falco/rules.d/falco_custom.yaml` with rules that help you to:
  - Find a Pod running image `httpd` which modifies `/etc/passwd`.
    - Scale the Deployment that controls that Pod down to 0.
  - Find a Pod running image `nginx` which triggers rule `Package management process launched`.
    - Change the rule log text after Package management process launched to only include:
      - `time-with-nanoseconds,container-id,container-name,user-name`
    - Collect the logs for at least 20 seconds and save them under `/course/2/falco.log`.
    - Scale the Deployment that controls that Pod down to 0.

---

- solution:

```sh
sudo -i

ssh node1

# output falco log and filter httpd
falco -U | grep httpd
# get pod name: rating-service-...; ns: team-violet

# scale down
k scale deploy rating-service -n team-violet --replicas=0

# confirm
k get deploy rating-service -n team-violet -o wide


ssh node1
# subtask: get pod
# get log for rule
falco -U | grep 'Package management process launched'
# get pod name: webapi-...; ns: team-clover


# subtask: update rule
vi /etc/falco# vim rules.d/falco_custom.yaml
# Package management process launched %evt.time,%container.id,%container.name,%user.name

# collect log
falco -M 20 > falco.log

scp falco.log controlplane:~

# controlplane
mv ~/falco.log /course/2/falco.log


# subtask: scale down
# scale down
k scale deploy webapi -n team-clover --replicas=0

# confirm
k get deploy webapi -n team-clover -o wide
```

---

## falco: syscall(killer B)

- task:
  - There are Pods in Namespace `team-tulip`. A security investigation noticed that some processes running in these Pods are using the Syscall `kill`, which is forbidden by an internal policy of Team Yellow.
  - Find the offending Pod(s) and remove these by reducing the replicas of the parent Deployment to 0.

---

- solution:

```sh
# get scheduling node
k -n team-tulip get pod -o wide

ssh node1

# define falco rule
vi /etc/falco/falco_rules.local.yaml
# - rule: rule name
#   desc: rule
#   condition: container and syscall. type = kill
#   output : "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk program | user=%user. name command=%proc. cmdline container=%container.id"
#   priority: WARNING

falco -U | grep kkkkkk
# get pod name
# get ns

k scale deploy --replicas=0
k get deploy
```

---

## falco: pod access /dev/mem

- a pod in defautl ns reach `/dev/mem`
- find it and scale to 0

---

- solution

IMPORTANT: in worker node

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Access Dev Mem
  desc: Detect container accessing /dev/mem
  condition: >
    evt.type in (open, openat, openat2)
    and container.id != host
    and fd.name = /dev/mem
  output: >
    DEV_MEM_ACCESS (container=%container.name id=%container.id file=%fd.name)
  priority: WARNING
```

```sh
systemctl restart falco
systemctl status falco

# test
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: devmem-test
spec:
  containers:
  - name: test
    image: busybox
    command:
    - sh
    - -c
    - |
      touch /dev/mem
      while true; do
        cat /dev/mem >/dev/null
        sleep 2
      done
EOF

kubectl delete po devmem-test --grace-period=0

journalctl _COMM=falco -f | grep DEV_MEM_ACCESS
# Oct 01 05:29:11 node01 falco[13755]: 05:29:11.244165973: Warning DEV_MEM_ACCESS (container=test id=4bf52a278e79 file=/dev/mem) container_id=4bf52a278e79 container_name=test container_image_repository=docker.io/library/busybox container_image_tag=latest k8s_pod_name=devmem-test k8s_ns_name=default
# Oct 01 05:29:11 node01 falco[13438]: 05:29:11.244163517: Warning DEV_MEM_ACCESS (container=test id=4bf52a278e79 file=/dev/mem) container_id=4bf52a278e79 container_name=test container_image_repository=docker.io/library/busybox container_image_tag=latest k8s_pod_name=devmem-test k8s_ns_name=default
```

---

## Task: falco - config,custom rule

There is suspicious activity in the cluster involving one of the pods running the `httpd:2.4-alpine` image.

Falco generates frequent alerts that start with: `File below a known binary directory opened for writing`.

Identify the rule causing this alert and update it as per the below requirements:

- Set the rule priority to `CRITICAL` (Note: Falco will format this as "Critical" in log output)
- The rule output must be:
  `File below a known binary directory opened for writing (user_id=%user.uid file_updated=%fd.name command=%proc.cmdline)`
- Configure alerts to be logged to: `/opt/security_incidents/alerts.log`.
  Do not update the default rules file directly. Instead, use the falco_rules.local.yaml file to override.

Expected log format:

```txt
<timestamp>: Critical File below a known binary directory opened for writing (user_id=0 file_updated=/bin/sleep command=tar -xmf - -C /bin)
```

Note: After updating the alert rule, it may take up to a minute for the alerts to appear in the new log location.

---

- solution:

Enable file_output in `/etc/falco/falco.yaml` on the controlplane node:

```yaml
file_output:
  enabled: true # important
  keep_alive: false
  filename: /opt/security_incidents/alerts.log
```

Next, add the updated rule under the `/etc/falco/falco_rules.local.yaml` and hot reload the Falco service:

```yaml
- rule: Write below binary dir
  desc: an attempt to write to any file below a set of binary directories
  condition: >
    bin_dir and evt.dir = < and open_write
    and not package_mgmt_procs
    and not exe_running_docker_save
    and not python_running_get_pip
    and not python_running_ms_oms
    and not user_known_write_below_binary_dir_activities
  output: >
    File below a known binary directory opened for writing (user_id=%user.uid file_updated=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [filesystem, mitre_persistence]
```

To perform hot-reload falco use '`kill -1 /SIGHUP`':

```sh
kill -1 $(cat /var/run/falco.pid)
```

Alternatively, you can also restart the falco service by running:

```sh
systemctl restart falco
```

---

## Task: falco - custom rule

Task
A pod in the `sahara` namespace has generated alerts that a shell was opened inside the container.

To recognize such alerts, set the priority to `ALERT` and change the format of the output so that it looks like the below:

```
ALERT timestamp of the event without nanoseconds,User ID,the container id,the container image repository
```

Make sure to update the rule such that the changes persist across Falco updates.

- setup

```yaml
# /etc/falco/falco_rules.yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    Shell is opened ...
  priority: ERROR
  tags: [container, shell, mitre_execution]
```

---

- **Solution**

Solution
Add the below rule to `/etc/falco/falco_rules.local.yaml` and restart the falco service to override the current rule.

```yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container with an attached terminal.
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: >
    %evt.time.s,%user.uid,%container.id,%container.image.repository
  priority: ALERT
  tags: [container, shell, mitre_execution]
```

Use the falco documentation to use the correct sysdig filters in the output.

For example, the evt.time.s filter prints the timestamp for the event without nano seconds. This is clearly described in the falco documentation here - https://falco.org/docs/rules/supported-fields/#evt-field-class

---

## Task: falco - find pod

Task
A pod in the `crypto-monitor` namespace is suspected of running crypto-mining software.
Create a Falco rule that detects the execution of known mining processes like `xmrig`, `minerd`, or `cpuminer`.

The rule should be added to `/etc/falco/falco_rules.local.yaml` with below specs:

- Trigger when any of these processes are executed: `xmrig`, `minerd`, `cpuminer`
- Set the priority to `CRITICAL`
- Output the format: `MINING_ALERT: %evt.time,%container.name,%proc.name`
- Tag the events with `[container, crypto_mining, mitre_execution]`

Make sure the rule persists across Falco updates by adding it to the local rules file.

---

- solution

```yaml
# vim /etc/falco/falco_rules.local.yaml
- rule: Detect Crypto Miner
  desc: Detect known crypto mining processes
  condition: >
    evt.type in (execve, execveat)
    and proc.name in (xmrig, minerd, cpuminer)
  output: "MINING_ALERT: %evt.time,%container.name,%proc.name"
  priority: CRITICAL
  tags: [container, crypto_mining, mitre_execution]
```

```sh
systemctl restart falco-modern-bpf

journalctl -u falco-modern-bpf --no-pager | tail -30
```

---

## falco - /etc/shadow

Task
A Pod is behaving improperly and poses a security threat to the system.

Task

A Pod belonging to the application analytics is abnormal. It is reading sensitive credential data by accessing the file `/etc/shadow`.

First, identify the misbehaving Pod that is accessing `/etc/shadow`.

Next, scale the Deployment of the misbehaving Pod down to zero replicas.

Notes

Do not modify anything else in that Deployment besides scaling replicas.
Do not modify any other Deployments.
Do not delete any Deployments.

---

- solution

```sh
journalctl -u falco-modern-bpf --no-pager | grep '/etc/shadow'
```

---
