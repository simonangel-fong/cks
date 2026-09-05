# CKS: Fundamental - `mTLS`

[back](../README.md)

- [CKS: Fundamental - `mTLS`](#cks-fundamental---mtls)
  - [`mTLS`](#mtls)
    - [Handshake process](#handshake-process)
    - [COnfiration Workflow Steps](#confiration-workflow-steps)

---

## `mTLS`

- The cluster components must meet the following security requirements:
  - Kubernetes components must **communicate** with each other over **secure channels**.
  - Components must **verify each other's identities**.

- `Mutual TLS (mTLS)`
  - a security protocol where both the **client** and the **server** **verify each other**'s identities using digital certificates before data flows.

- `standard TLS`: only the client checks if the server is real
  - risk: `Man-in-the-Middle (MitM)` impersonation attack

- requirements
  - both has its own certificate
  - both certs are signed by CA trusted by both sender and receiver.

---

### Handshake process

1. The **client** connects to the server.
2. The **server** presents its **certificate** to the client.
3. The **client** verifies the server's certificate.
4. The **client** presents its **certificate** to the server.
5. The **server** verifies the client's certificate.
6. If both verifications pass, a secure, **encrypted connection** is established.

---

### COnfiration Workflow Steps

1. Certificate Authority.
2. Etcd certificate signed through the Certificate Authority.
3. Client certificate signed through the Certificate Authority.
4. Both etcd and client will trust the Certificate Authority

---
