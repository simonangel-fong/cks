# CKS: Secret

[Back](../README.md)

- [CKS: Secret](#cks-secret)
  - [Secret](#secret)
    - [Secure secret](#secure-secret)

---

## Secret

- used to store sensitive data.
- apply:
  - create secret
  - reference secret in pod:
    - volume mount
    - environment variable

---

### Secure secret

- By default, `Secrets` are stored in data store (ETCD) in plain text.
  - should encrypt the `etcd`
- protect access to secrets using RBAC for access control
