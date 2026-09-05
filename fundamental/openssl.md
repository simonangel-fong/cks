# CKS: Fundamental - openssl

[back](../README.md)

- [CKS: Fundamental - openssl](#cks-fundamental---openssl)
  - [Create private key](#create-private-key)
  - [Create csr](#create-csr)
  - [Sign CSR](#sign-csr)
  - [Display certificate](#display-certificate)
  - [verify](#verify)


## Create private key

```sh
openssl genrsa -out etcd.key 2048
```

| Parameter      | DSC                                    |
| -------------- | -------------------------------------- |
| openssl genrsa | use the RSA key generation utility.    |
| -out etcd.key  | Output File                            |
| 2048           | The cryptographic strength of the key. |

## Create csr

```sh
openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr -config etcd.cnf
```

| Parameter        | DSC                                                           |
| ---------------- | ------------------------------------------------------------- |
| openssl req      | use the X.509 Certificate Signing Request management utility. |
| -new             | Generates a brand new CSR                                     |
| -key etcd.key    | Links this request to the private key                         |
| -subj "/CN=etcd  | Subject Details to inject into csr                            |
| -out etcd.csr    | output file                                                   |
| -config etcd.cnf | config file to inject advanced attributes                     |

## Sign CSR

```sh
openssl x509 -req -in etcd.csr -CA ~/cert/ca/ca.crt -CAkey ~/cert/ca/ca.key -CAcreateserial -out etcd.crt -extensions v3_req -extfile etcd.cnf -days 2000
```

| Option                  | DSC                                                                  |
| ----------------------- | -------------------------------------------------------------------- |
| x509                    | use the X.509 certificate utility                                    |
| -req                    | Specifies that the input file is a Certificate Signing Request (CSR) |
| -in etcd.csr            | input CSR file                                                       |
| -CA ~/cert/ca/ca.crt    | CA Certificate used to sign cert                                     |
| -CAkey ~/cert/ca/ca.key | CA Private Key used to sign cert                                     |
| -CAcreateserial         | Automatically creates a unique serial number file                    |
| -out etcd.crt           | Output File                                                          |
| -extensions v3_req      | Extension Section defined in the [ v3_req ] block in the config file |
| -extfile etcd.cnf       | Points to a configuration text file with properties                  |
| -days 2000              | Validity Period                                                      |

## Display certificate

```sh
openssl x509 -in etcd.crt -text -noout
```

| Parameter    | DESC                                          |
| ------------ | --------------------------------------------- |
| openssl x509 | Use X.509 Utility                             |
| -in etcd.crt | input cert file                               |
| -text        | Translates into a human-readable text report. |
| -noout       | Suppress Encoded Output                       |

## verify

```sh
openssl verify -CAfile ~/cert/ca/ca.crt etcd.crt
```

| Parameter                | DESC                                                   |
| ------------------------ | ------------------------------------------------------ |
| openssl verify           | use Verification Utility                               |
| -CAfile ~/cert/ca/ca.crt | Specifies the explicit Root Certificate Authority file |
| etcd.crt                 | Target File                                            |
