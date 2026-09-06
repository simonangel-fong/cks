## Hash

- `Hashing`
  - a one-way function that maps data of **arbitrary size** (often called the "message") to a bit array of a **fixed size** (message digest)

- command tools
  - `md5sum`
  - `sha512sum`

```sh
cat > message.txt<<EOF
this is a message
EOF

md5sume message.txt
# 1fb0076c4f2eaa1c788679154c51aa89  message.txt

sha512sum message.txt
# 938ae2554fbd292d8aaeda30bb947bd39f94fe91d481dc3e1532f8c99a490fd1b9a6aded57ea9d3f9a46cb6bd576d966b8b11a05bfe8bec683ffcc0b807d51ac  message.txt
```

---

### Verify Platform Binaries

- verify the integrity of the archive by comparing
  - a **hash** of the archive file
  - **hash** value posted in the official website.

- client binary url: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.37.md#client-binaries
  - kubernetes-client-linux-amd64.tar.gz: https://dl.k8s.io/v1.37.0/kubernetes-client-linux-amd64.tar.gz
  - sha512 hash: ff61f94cf73281e24b8b7f16bd7ae15a928ef886399a2e8a360c170828babade73aeb284d37c596fc6c7dc68876b1550b714c1fc3ac4263adb8aef9e30a7c42f

```sh

# download
cd /tmp/
wget https://dl.k8s.io/v1.37.0/kubernetes-client-linux-amd64.tar.gz
# --2026-09-06 15:56:31--  https://dl.k8s.io/v1.37.0/kubernetes-client-linux-amd64.tar.gz
# Resolving dl.k8s.io (dl.k8s.io)... 2a04:4e42:400::347, 2a04:4e42:600::347, 2a04:4e42::347, ...
# Connecting to dl.k8s.io (dl.k8s.io)|2a04:4e42:400::347|:443... connected.
# HTTP request sent, awaiting response... 200 OK
# Length: 36104933 (34M) [application/x-tar]
# Saving to: ‘kubernetes-client-linux-amd64.tar.gz’

# kubernetes-client-linux-amd64.tar.g 100%[===================================================================>]  34.43M  20.6MB/s    in 1.7s

# 2026-09-06 15:56:32 (20.6 MB/s) - ‘kubernetes-client-linux-amd64.tar.gz’ saved [36104933/36104933]

sha512sum kubernetes-client-linux-amd64.tar.gz
# ff61f94cf73281e24b8b7f16bd7ae15a928ef886399a2e8a360c170828babade73aeb284d37c596fc6c7dc68876b1550b714c1fc3ac4263adb8aef9e30a7c42f  kubernetes-client-linux-amd64.tar.gz
```
