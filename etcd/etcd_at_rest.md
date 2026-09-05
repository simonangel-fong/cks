#

### Secure data storage at rest

- By defautl, etcd stores data **in plain text.**
  - sensitive data, e.g., secrets, can be read directly from the disk.

## Lab: Storage in plain text

- install etcd

```sh
cd /tmp
export ETCD_VERSION=v3.6.14
curl -fLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"

tar -xzf "etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

ls -l
# total 60664
# drwxr-xr-x 6 ubuntuadmin ubuntuadmin     4096 Jul 23 15:21 Documentation
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin    44075 Jul 23 15:21 README-etcdctl.md
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin     8275 Jul 23 15:21 README-etcdutl.md
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin     9839 Jul 23 15:21 README.md
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin     7896 Jul 23 15:21 READMEv2-etcdctl.md
# -rwxr-xr-x 1 ubuntuadmin ubuntuadmin 26734776 Jul 23 15:21 etcd
# -rwxr-xr-x 1 ubuntuadmin ubuntuadmin 17567928 Jul 23 15:21 etcdctl
# -rwxr-xr-x 1 ubuntuadmin ubuntuadmin 17723576 Jul 23 15:21 etcdutl

# raw start
./etcd

# confirm ports
sudo ss -ntlp | grep -E "2379|2380"
# LISTEN 0      4096        127.0.0.1:2380      0.0.0.0:*    users:(("etcd",pid=2602,fd=4))
# LISTEN 0      4096        127.0.0.1:2379      0.0.0.0:*    users:(("etcd",pid=2602,fd=7))

# confirm connection without tls
./etcdctl --endpoints=http://127.0.0.1:2379 endpoint health
# http://127.0.0.1:2379 is healthy: successfully committed proposal: took = 2.530133ms
```

- insert a kv pair
  - without auth
  - communicate in plain text, http, not https
  - store data in plain text

```sh
# insert a kv pair
cd "/tmp/etcd-${ETCD_VERSION}-linux-amd64"

./etcdctl --endpoints=http://127.0.0.1:2379 put message "test,test,test"
# OK

# query data
./etcdctl --endpoints=http://127.0.0.1:2379 get message
# message
# test,test,test

# confirm plain text
grep -R "test,test,test" .
# grep: ./default.etcd/member/snap/db: binary file matches
# grep: ./default.etcd/member/wal/0000000000000000-0000000000000000.wal: binary file matches

```
