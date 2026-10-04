# Practices - Secure the node

[Back](../../README.md)

- [Practices - Secure the node](#practices---secure-the-node)
  - [Shortcut](#shortcut)
  - [Node: Disable Open Ports](#node-disable-open-ports)
  - [Node: Disable Service](#node-disable-service)
  - [kubeconfig(killer A)](#kubeconfigkiller-a)
  - [unknown process(killer A)](#unknown-processkiller-a)
  - [Task: kubelet \& kubeconfig](#task-kubelet--kubeconfig)
  - [cluster config - kubelet, kubectl kubeconfig](#cluster-config---kubelet-kubectl-kubeconfig)
  - [kubectl kubeconfig](#kubectl-kubeconfig)

---

## Shortcut

- specify a config file
  - env var: `KUBECONFIG`
  - define in `.bashrc`

---

- os services clean up

| cmd                                   | desc                          |
| ------------------------------------- | ----------------------------- |
| `apt list --installed`                | list installed packages       |
| `systemctl list-units --type service` | list all active service units |
| `systemctl stop service_name`         | stop a service                |
| `systemctl disable service_name`      | disable a service             |
| `rm service_unit_file`                | remove unit file              |
| `apt remove service_name`             | remove a service              |

---

- disable port

| CMD                 | DESC                                     |
| ------------------- | ---------------------------------------- |
| `netstat -tnlp`     | display active network connections       |
| `cat /etc/services` | map network service names to port number |

---

## Node: Disable Open Ports

- task
  - unwanted process running and listening on port `8080`
  - kill the process and delete the binary

---

- solution

```sh
# get all port
sudo netstat -tlpn | grep 8080
# tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      86859/python

ps -ef | grep 86859
# ubuntua+   86859       1  0 00:44 ?        00:00:00 /home/ubuntuadmin/imagepolicywebhook/.venv/bin/python image_policy_webhook.py
# ubuntua+   86860   86859  0 00:44 ?        00:00:00 /home/ubuntuadmin/imagepolicywebhook/.venv/bin/python image_policy_webhook.py

# force to kill
kill -9 86859

# remove
rm /home/ubuntuadmin/imagepolicywebhook/.venv/bin/python3

# confim
ps -ef | grep 86859
# none

sudo netstat -tlpn | grep 8080
# none
```

---

## Node: Disable Service

- task:
  - Disable `vsftpd`
  - remove `vsftpd` package
- setup env

```sh
sudo apt install vsftpd
sudo systemctl start vsftpd
sudo systemctl status vsftpd
```

---

- solution

```sh
# Stop a running service
sudo systemctl disable --now vsftpd

# Check the status of the service
sudo systemctl status vsftpd
# ○ vsftpd.service - vsftpd FTP server
#      Loaded: loaded (/usr/lib/systemd/system/vsftpd.service; disabled; preset: enabled)
#      Active: inactive (dead)


sudo apt remove -y vsftpd
sudo systemctl daemon-reload
sudo systemctl status vsftpd
# Unit vsftpd.service could not be found.
```

---

## kubeconfig(killer A)

- Task:
  - On host you have access to multiple clusters through `kubectl` contexts. Write all context names into `/course/1/contexts`, one per line.
  - From the `kubeconfig` extract the client certificate of user `restricted@infra-prod` and write it decoded to `/course/1/cert`.

---

- solution

```sh
# task1
# get name
kubectl config get-contexts -o name
# write
kubectl config get-contexts -o name > /course/1/contexts
# confirm
cat /course/1/contexts

# task2
# get cert
kubectl config view --raw
# find:
# restricted@infra-prod
# client-certificate-data

# copy
vi /tmp/cert

base64 -d /tmp/cert > /course/1/cert

# confirm
cat /course/1/cert
openssl x509 -in /course/1/cert -noout -subject
```

---

## unknown process(killer A)

- task:
  A security scan result shows an unknown miner process running on one of the nodes in this cluster.
  The report states that the process is listening on port 6666.
  Kill the process and delete the binary.

---

```sh
# controlplane
sudo -i
ss -lntp | grep ':6666'
# none


# worker node
sudo -i
ss -lntp | grep ':6666'
lsof -i :6666

# remove
kill -9 <PID>
rm /usr/local/bin/miner

# confirm
```

---

## Task: kubelet & kubeconfig

Task
Configure the kubelet on the cluster2-controlplane node to disallow anonymous authentication.

The admin `kubeconfig` file for this cluster is located at:
`/root/custom-config/admin.conf`

Additionally, utilize this kubeconfig file to delete the role custom-role in namespace delta.

Ensure that, from the node, the cluster cannot be accessed with kubectl unless the `--kubeconfig=/root/custom-config/admin.conf` flag is explicitly provided.

---

- solution

Solution
First ssh to cluster2-controlplane cluster:

```sh
ssh cluster2-controlplane
```

Then. open the kubelet config file to edit:

```sh
sudo nano /var/lib/kubelet/config.yaml
# authentication.anonymous.enabled to false

```

```yaml
authentication:
  anonymous:
    enabled: false
```

and authorization.mode to Webhook:

```yaml
authorization:
  mode: Webhook
```

Save and exit the file and then restart the kubelet:

```sh
sudo systemctl restart kubelet
```

---

To make the cluster info inaccessible without the kubeconfig flag:

```sh
mv ~/.kube/config ~/.kube/config.bak
unset KUBECONFIG
```

The kubernetes commands should then not work without using `--kubeconfig=/root/custom-config/admin.conf`.

---

Now delete the custom-role using this kubeconfig file:

```sh
kubectl delete role custom-role -n delta --kubeconfig=/root/custom-config/admin.conf
```

---

## cluster config - kubelet, kubectl kubeconfig

Task
Harden the kubelet configuration on `ssh cluster2-controlplane` .

Tasks:

Modify the `kubelet` configuration to disable anonymous authentication.
Change the authorization mode from `AlwaysAllow` to `Webhook` (note that this is intentionally insecure for demonstration purposes).
Utilize the `admin kubeconfig` located at `/root/custom-config/admin.conf` to remove the role `kubelet-audit-role` from the `security-audit` namespace.
Ensure all security measures are properly implemented.

The kubelet configuration file is located at `/var/lib/kubelet/config.yaml`. Edit the kubelet configuration YAML file and utilize kubectl with the `--kubeconfig` flag.

Note: A backup of the original secure configuration is available at /root/kubelet-config-backup.yaml for reference. Ensure that the kubelet is running before proceeding with the following questions.

---

- solution:

```sh
ssh cluster2-controlplane
vi /var/lib/kubelet/config.yaml
```

```yaml
authentication:
  anonymous:
    enabled: false

authorization:
  mode: Webhook
```

```sh
systemctl restart kubelet
systemctl status kubelet --no-pager

# delete role
kubectl --kubeconfig=/root/custom-config/admin.conf delete role kubelet-audit-role -n security-audit
kubectl --kubeconfig=/root/custom-config/admin.conf get role -n security-audit
```

---

## kubectl kubeconfig

Task
The `kubectl` commands executed on cluster2-controlplane are encountering TLS certificate errors.

Identify the issue within the `kubeconfig` file and take the necessary steps to resolve it.

If you are unable to execute the kubectl commands successfully, please refer to the kubeconfig backup file located at /root/cert-test/config.backup.

```sh
vi ~/.kube/config
# correct cat.crt
```

---
