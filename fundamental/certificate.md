# CKS: Fundamental - certificate

[back](../README.md)

- [CKS: Fundamental - certificate](#cks-fundamental---certificate)
  - [Certificate Authority](#certificate-authority)
    - [Certificate Creation Workflow](#certificate-creation-workflow)
  - [Lab: Create Certificates](#lab-create-certificates)
    - [1. Create a Root CA](#1-create-a-root-ca)
    - [2. Create a Client Certificate](#2-create-a-client-certificate)

---

## Certificate Authority

- A `certificate authority (CA)` establishes trust between communicating parties.
  - A CA is an **entity** that **issues** digital certificates.
  - Both the **sender** and the **receiver** **trust** the `CA`.

- A `CA` serves two main purposes in Kubernetes:
  - It issues `server certificates` for **secure TLS communication**.
    - Clients use a trusted CA certificate to verify the server's certificate.
  - It issues `client certificates` to **authenticate** users and components.
    - For certificate-based authentication, the server **verifies** the client's `certificate` against a trusted `CA`.

---

- important fields:
  - `Common Name (CN)`: username
  - `Organization (O)`: group name
- e.g.,
  - `openssl req -new -key alice.key -subj "/CN=alice/O=admins" -out alice.csr`
  - The above commands create CSR for the **username alice** belonging to **admins group**

---

### Certificate Creation Workflow

The certificate creation workflow consists of two main stages:

1. Generate the CA's private key and certificate.
2. Create a client certificate signed by the CA:
   1. Generate a private key and a certificate signing request (CSR) for the client or component.
   2. Sign the CSR using the CA's private key and certificate to issue the client certificate.

---

## Lab: Create Certificates

### 1. Create a Root CA

```sh
mkdir -pv ~/cert/ca
# mkdir: created directory '/home/ubuntuadmin/cert'
# mkdir: created directory '/home/ubuntuadmin/cert/ca'
cd ~/cert/ca

# Create the CA's private key.
openssl genrsa -out ca.key 2048
cat ca.key
# -----BEGIN PRIVATE KEY-----
# MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQD0k9lxlg1s4eQi
# C21H6lYQoWJIlkAzOOn43OCivhKKPPh+W1oVNgvZ4JQ3uXt5lVRJUyH0nPaP3JSa
# gp2Wbqqo4liOSU1OlTrE/1G3NPiOb+e4PRBrLFbtPwWPSrVh7vaJIPOfnXNVtQEc
# R5iUJ/LDtnb6Ky6w0KsnRGGKfCMrLbMX1+afIB2WTqkuGKBrVnuXEBRRWG9b4yQ3
# wLNtr2BxLEHUVbEWUwgNgmr2v6Pio9CPB/mvR74+QgP4sZsg7
# ...

# Create a certificate signing request (CSR).
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr

cat ca.csr
# -----BEGIN CERTIFICATE REQUEST-----
# MIICXTCCAUUCAQAwGDEWMBQGA1UEAwwNS1VCRVJORVRFUy1DQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPST2XGWDWzh5CILbUfqVhChYkiWQDM46fjc
# 4KK+Eoo8+H5bWhU2C9nglDe5e3mVVElTIfSc9o/clJqCnZZuqqjiWI5JTU6VOsT/
# Ubc0+I5v57g9EGssVu0/BY9KtWHu9okg85+dc1W1ARxHmJQn8sO2dvorLrDQqydE
# ...

# Create a self-signed certificate using the CA's private key.
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000
# Certificate request self-signature ok
# subject=CN = KUBERNETES-CA

cat ca.crt
# -----BEGIN CERTIFICATE-----
# MIICtzCCAZ8CFC4EDQeimK6IzycJnffu3TGd/zmHMA0GCSqGSIb3DQEBCwUAMBgx
# FjAUBgNVBAMMDUtVQkVSTkVURVMtQ0EwHhcNMjYwOTA0MjEwOTA1WhcNMjkwNTMx
# ...

# Remove the CSR.
rm -fv ca.csr
# removed 'ca.csr'

ll
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin 1001 Sep  4 17:09 ca.crt
# -rw------- 1 ubuntuadmin ubuntuadmin 1708 Sep  4 17:07 ca.key

# Inspect the certificate's contents.
openssl x509 -in ca.crt -text -noout
# Certificate:
#     Data:
#         Version: 1 (0x0)
#         Serial Number:
#             2e:04:0d:07:a2:98:ae:88:cf:27:09:9d:f7:ee:dd:31:9d:ff:39:87
#         Signature Algorithm: sha256WithRSAEncryption
#         Issuer: CN = KUBERNETES-CA
#         Validity
#             Not Before: Sep  4 21:09:05 2026 GMT
#             Not After : May 31 21:09:05 2029 GMT
#         Subject: CN = KUBERNETES-CA
#         Subject Public Key Info:
#             Public Key Algorithm: rsaEncryption
#                 Public-Key: (2048 bit)
#                 Modulus:
#                     00:f4:93:d9:71:96:0d:6c:e1:e4:22:0b:6d:47:ea:
#                     56:10:a1:62:48:96:40:33:38:e9:f8:dc:e0:a2:be:
#                     12:8a:3c:f8:7e:5b:5a:15:36:0b:d9:e0:94:37:b9:
#                     7b:79:95:54:49:53:21:f4:9c:f6:8f:dc:94:9a:82:
#                     9d:96:6e:aa:a8:e2:58:8e:49:4d:4e:95:3a:c4:ff:
#                     51:b7:34:f8:8e:6f:e7:b8:3d:10:6b:2c:56:ed:3f:
#                     05:8f:4a:b5:61:ee:f6:89:20:f3:9f:9d:73:55:b5:
#                     01:1c:47:98:94:27:f2:c3:b6:76:fa:2b:2e:b0:d0:
#                     ab:27:44:61:8a:7c:23:2b:2d:b3:17:d7:e6:9f:20:
#                     1d:96:4e:a9:2e:18:a0:6b:56:7b:97:10:14:51:58:
#                     6f:5b:e3:24:37:c0:b3:6d:af:60:71:2c:41:d4:55:
#                     b1:16:53:08:0d:82:6a:f6:bf:a3:e2:a3:d0:8f:07:
#                     f9:af:47:be:3e:42:03:f8:b1:9b:20:ee:30:7e:87:
#                     8d:a2:e5:23:fe:e6:a9:8d:39:74:e8:f1:12:a4:43:
#                     72:67:66:f9:1f:c4:d1:96:fd:c0:9f:03:e6:db:fd:
#                     c9:4b:96:35:1b:14:e8:b4:0b:1d:84:8b:2f:48:62:
#                     5a:46:17:23:6a:87:7e:e3:5c:5e:70:c6:4e:3d:7b:
#                     7a:d1
#                 Exponent: 65537 (0x10001)
#     Signature Algorithm: sha256WithRSAEncryption
#     Signature Value:
#         32:9a:68:f1:cc:ca:83:19:84:3a:66:79:40:a1:92:86:53:64:
#         42:65:8f:d8:66:28:eb:6d:c3:b5:86:a9:6a:99:e7:45:10:73:
#         c2:60:d1:6c:68:b9:6a:8b:91:bb:ae:25:fe:c1:6f:82:6b:1c:
#         19:df:99:de:36:94:81:77:75:4b:63:64:78:be:00:50:a6:46:
#         10:e5:7d:c8:4d:63:e1:3d:8d:07:73:69:64:40:0d:1c:f3:79:
#         75:2e:d1:e7:6e:b0:df:b8:94:5f:6b:30:4a:0c:aa:49:b5:c9:
#         3a:17:c1:4b:80:d9:47:5a:f4:95:6c:8b:df:1c:68:21:cf:ff:
#         3e:01:ec:88:6c:76:c7:20:10:e9:62:6c:7f:7b:e9:be:9e:0a:
#         ff:64:52:fe:38:3c:88:72:b9:c2:38:08:86:f4:b5:b4:fa:86:
#         68:35:fd:96:a3:86:32:76:14:a5:e4:20:b5:76:18:f4:d0:9c:
#         c2:af:c3:5a:71:44:50:73:4c:d2:62:eb:72:6f:9e:9c:d9:33:
#         72:f2:56:d7:57:4f:dc:66:62:cf:2c:86:38:80:25:d9:de:63:
#         68:99:62:f2:3b:43:22:0d:7b:27:d4:b0:00:ec:18:1e:a8:d3:
#         ad:ac:7a:9a:0c:b4:31:71:bb:6c:9a:e8:3d:de:75:e1:c6:7f:
#         1e:f3:24:96
```

---

### 2. Create a Client Certificate

- Create the client's private key and a `certificate signing request (CSR)`.
  - Save them as `client.key` and `client.csr`, respectively.
- Create the client certificate by signing the client's CSR using the CA's private key and certificate.
  - Save the signed certificate as `client.crt`.

```sh
mkdir -pv ~/cert/client
# mkdir: created directory '/home/ubuntuadmin/cert/client'
cd ~/cert/client

# ##############################
# Create the client's private key and CSR.
# ##############################

# Create the client's private key.
openssl genrsa -out client.key 2048

# Create a certificate signing request (CSR).
openssl req -new -key client.key -subj "/CN=client" -out client.csr

# ##############################
# Sign the client's CSR using the CA.
# ##############################
# Sign the CSR and save the client certificate.
openssl x509 -req -in client.csr -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -out client.crt -days 1000
# Certificate request self-signature ok
# subject=CN = client

# Display the certificate's contents in plain text.
openssl x509 -in client.crt -text -noout
# Certificate:
    # Data:
    #     Version: 1 (0x0)
    #     Serial Number:
    #         0d:26:52:98:6f:b9:f7:54:18:23:ba:80:6a:03:72:d4:97:bb:38:f3
    #     Signature Algorithm: sha256WithRSAEncryption
    #     Issuer: CN = KUBERNETES-CA
    #     Validity
    #         Not Before: Sep  5 00:53:32 2026 GMT
    #         Not After : Jun  1 00:53:32 2029 GMT
    #     Subject: CN = client
    #     Subject Public Key Info:
    #         Public Key Algorithm: rsaEncryption
    #             Public-Key: (2048 bit)
    #             Modulus:
    #                 00:c3:02:27:93:04:05:43:1b:2e:ac:64:09:3c:e3:
    #                 b7:10:ed:9c:ee:4c:45:5f:d2:44:3e:ca:a3:ed:98:
    #                 0b:63:04:34:6e:09:2f:d3:a1:0a:52:51:47:89:19:
    #                 90:fb:05:c2:91:05:d3:0f:08:27:c0:68:9c:3a:51:
    #                 65:32:8b:ab:2a:8e:5d:5a:05:ec:a5:f6:eb:7f:99:
    #                 50:29:96:29:4e:4b:23:5e:fc:5e:72:be:ca:9e:20:
    #                 c4:72:4f:d6:6d:b4:c2:92:8e:e5:bc:cb:a2:83:ee:
    #                 92:67:b9:77:46:3e:16:2e:76:3b:e8:d1:20:31:c6:
    #                 1b:6c:de:86:fc:de:98:ac:e7:d1:9c:8f:64:ed:39:
    #                 8f:6f:e1:37:3a:87:f8:3d:ac:25:9a:de:e2:2f:72:
    #                 64:f2:98:bd:5b:08:f7:d1:46:80:17:11:d2:8d:7b:
    #                 a7:c2:1c:88:8b:18:8e:a4:14:da:9d:9e:43:28:fe:
    #                 5d:41:38:97:2a:13:8e:b0:42:93:3d:a4:d5:65:c9:
    #                 27:ce:b0:b7:61:88:d0:20:d6:31:45:de:56:47:1e:
    #                 7e:89:1c:99:23:ee:e3:f7:a3:7f:0d:07:cd:a9:b5:
    #                 03:bb:e3:0c:43:78:2f:1c:8c:57:a7:5d:fc:40:2a:
    #                 1d:d4:e2:c2:4d:20:7b:f6:02:30:c1:44:bb:95:0e:
    #                 21:b9
    #             Exponent: 65537 (0x10001)
    # Signature Algorithm: sha256WithRSAEncryption
    # Signature Value:
    #     42:84:76:64:8b:c0:07:bf:ce:45:90:2d:70:57:45:f9:68:0f:
    #     77:04:3a:46:c5:d2:94:1e:a1:8d:29:4e:d6:04:10:21:64:f9:
    #     8d:de:da:a3:3b:97:4b:9d:6d:0c:ff:5e:90:92:df:04:7f:b4:
    #     37:2f:ee:04:ba:60:3f:c3:ab:f0:c1:15:b3:16:cb:30:d2:02:
    #     9b:c9:eb:d5:57:ac:ec:07:ee:79:86:7e:fb:8b:0d:29:62:69:
    #     1b:ab:77:67:67:f7:1c:0f:36:a7:a3:f2:eb:19:5b:3f:8f:9f:
    #     8e:8c:6a:fc:60:09:79:0e:b9:e6:84:f0:5f:be:45:15:b0:79:
    #     a1:c3:d1:7f:14:c4:8b:d0:b1:c2:d1:9b:d5:a9:0f:1a:67:d8:
    #     81:9d:8c:25:ea:ca:8a:d9:ba:44:51:79:7a:b1:a3:60:c8:e9:
    #     0c:85:e3:65:f1:99:9f:1c:06:61:8f:53:f0:6d:48:35:3c:85:
    #     39:29:3c:c3:8e:0c:56:57:3d:72:5e:94:a2:18:65:b8:63:bb:
    #     5c:c8:cf:d4:72:d5:7c:1e:64:0d:09:c0:b1:c9:63:00:6e:5e:
    #     c7:8a:84:23:f2:b5:27:8c:bf:c0:51:52:23:a1:e7:0f:2b:d7:
    #     64:ec:71:0e:27:1f:7a:9e:ca:7b:90:9a:57:35:c3:cc:6e:b6:
    #     c5:6e:2f:2b

# Verify the client certificate against the CA certificate.
openssl verify -CAfile ~/cert/ca/ca.crt client.crt
# client.crt: OK

# Remove the CSR.
rm client.csr

# Confirm that the client certificate and private key exist.
ll ~/cert/client
# total 16
# drwxr-xr-x 2 ubuntuadmin ubuntuadmin 4096 Sep  4 20:58 ./
# drwxr-xr-x 4 ubuntuadmin ubuntuadmin 4096 Sep  4 20:52 ../
# -rw-r--r-- 1 ubuntuadmin ubuntuadmin  993 Sep  4 20:53 client.crt
# -rw------- 1 ubuntuadmin ubuntuadmin 1708 Sep  4 20:53 client.key
```

---
