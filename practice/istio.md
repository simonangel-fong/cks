# Practices - Istio

[Back](../README.md)

- [Practices - Istio](#practices---istio)
  - [Istio](#istio)

---

- Istio
  - Enable istio-proxy injection in a namespace
    - `kubectl label namespace target-namespace istio-injection=enabled --overwrite=true`
    - https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/#deploying-an-app
  - Enforce strict mTLS in the namespace.
    - https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/#lock-down-to-mutual-tls-by-namespace

## Istio
