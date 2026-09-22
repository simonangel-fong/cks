# Practices - falco

[Back](../../README.md)

- [Practices - falco](#practices---falco)
  - [Shortcut](#shortcut)
  - [falco: rule pod sh???](#falco-rule-pod-sh)
  - [falco(killer A)](#falcokiller-a)
  - [falco(killer B)](#falcokiller-b)

---

## Shortcut

- Falco
  - Be prepared to develop a `Falco rule` according to a given specification.
  - If you encounter issues with **Falco log generation**, verify that `syslog` is enabled with **debug priority**.
  - Alternatively, run `Falco` directly from the **command line**, bypassing `systemd`.

| CMD                      | DESC                              |
| ------------------------ | --------------------------------- |
| `falco -U`               | unbuffered and immediately output |
| `falco -U \| grep httpd` | keep lines containing “httpd”     |

---

## falco: rule pod sh???

- context;
  - falco is installed and running
- task:
  - confirm falco is monitoring cluster
  - create a pod name `web-app` using `nginx:alpine`
  - `kubectl exec -it web-app -- sh`
  - check falco logs

---

- solution

```sh
# confirm falco is running
systemctl status falco
# ● falco-modern-bpf.service - Falco: Container Native Runtime Security with modern ebpf
#      Loaded: loaded (/usr/lib/systemd/system/falco-modern-bpf.service; enabled; preset: enabled)
#      Active: active (running) since Tue 2026-09-15 08:29:44 EDT; 51min ago
#        Docs: https://falco.org/docs/
#    Main PID: 8472 (falco)
#       Tasks: 18 (limit: 7689)
#      Memory: 72.0M (peak: 457.6M)
#         CPU: 38.029s
#      CGroup: /system.slice/falco-modern-bpf.service

sudo journalctl _COMM=falco -f


kubectl run web-app --image=nginx
# pod/web-app created

kubectl exec -it web-app -- sh

journalctl -fu falco

cat /var/log/syslog | grep falco
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
