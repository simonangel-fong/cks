# # CKS: `kube-apiserver` Security

[Back](../README.md)

- [# CKS: `kube-apiserver` Security](#-cks-kube-apiserver-security)
  - [Secure connection to `etcd`](#secure-connection-to-etcd)
    - [Secure connection with TLS](#secure-connection-with-tls)

---

## Secure connection to `etcd`

- apiserver required coennection to `etcd`
- configure apiserver with `etcd` client certificate
  - `--etcd-certfile` / `--etcd-keyfile`: client certificate
  - `--etcd-cafile=`: ca file

---

### Secure connection with TLS

- By default, apiserver enables https by a **self-signed** certificate.
- Secure connection by encrypting connection via trusted certificate.

- encrypt connection with TLS
  - `--tls-cert-file` / `--tls-private-key-file`: serve HTTPS to API clients.

- workflow:
  - create apiserver certificate
  - apply certificate in flags

- api server port: 6443

```sh
# get the https certificate info
openssl s_client -showcerts -connect localhost:6443 2>/dev/null | openssl x509 -inform pem -noout -text | grep -E "Issuer:|Subject:"
        # Issuer: CN = KUBERNETES-CA
        # Subject: CN = kube-apiserver
```

---
