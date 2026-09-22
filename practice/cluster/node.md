# Practices - Secure the node

[Back](../../README.md)

- [Practices - Secure the node](#practices---secure-the-node)
  - [Node: Disable Open Ports](#node-disable-open-ports)
  - [Node: Disable Service](#node-disable-service)
  - [kubeconfig(killer A)](#kubeconfigkiller-a)
  - [unknown process(killer A)](#unknown-processkiller-a)

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
