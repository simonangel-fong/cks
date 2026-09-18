# Practices - Secure the node

[Back](../README.md)

- [Practices - Secure the node](#practices---secure-the-node)
  - [Disable Open Ports](#disable-open-ports)
  - [Disable Service](#disable-service)

---

## Disable Open Ports

- question
  - unwanted process running and listening on port `2379`
  - kill the process and delete the binary

- solution

```sh
# get all port
sudo ss -tlpn | grep 2379
# LISTEN 0      4096        127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=2309,fd=6))
# LISTEN 0      4096   192.168.10.150:2379       0.0.0.0:*    users:(("etcd",pid=2309,fd=7))

sudo ls -l /proc/2309/exe
# lrwxrwxrwx 1 root root 0 Sep 14 08:09 /proc/2309/exe -> /usr/local/bin/etcd

sudo lsof -i :2379
# COMMAND     PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
# etcd       2309 root    6u  IPv4   25542      0t0  TCP localhost:2379 (LISTEN)
# etcd       2309 root    7u  IPv4   25544      0t0  TCP controlplane:2379 (LISTEN)
# etcd       2309 root    9u  IPv4  418593      0t0  TCP localhost:2379->localhost:41892 (ESTABLISHED)
# etcd       2309 root   13u  IPv4  419507      0t0  TCP localhost:2379->localhost:41918 (ESTABLISHED)

# force to kill
kill -9 2309

# remove
rm /usr/local/bin/etcd
```

---

## Disable Service

- setup env

```sh
sudo apt install vsftpd
sudo systemctl start vsftpd
sudo systemctl status vsftpd
```

```sh
# Stop a running service
sudo systemctl stop vsftpd

# Check the status of the service
sudo systemctl status vsftpd

sudo apt remove vsftpd
```

---
