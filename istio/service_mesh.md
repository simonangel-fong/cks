# CKS: Istio - Service Mesh

[Back](../README.md)

- [CKS: Istio - Service Mesh](#cks-istio---service-mesh)
  - [Service Mesh](#service-mesh)
    - [Challenges with Microservices Architecture](#challenges-with-microservices-architecture)
    - [service mesh](#service-mesh-1)
  - [Istio](#istio)
    - [Envoy](#envoy)
    - [Security](#security)
    - [Monitoring](#monitoring)

---

## Service Mesh

### Challenges with Microservices Architecture

- When your application is broken down into dozens or hundreds of services, managing the communication between them becomes a major hurdle.

- **Secure Communication**: How can we ensure that all data exchanged between services is **encrypted** and that services can verify each other's **identity** to prevent man-in-the-middle attacks?
- **Network Isolation**: How to allow only whitelisted service to communicate with other service.
- **Service Discovery**: How does a service find the network location (IP address) of another service it needs to talk to, especially in a dynamic environment where containers are constantly changing?
- **Monitoring**: How do we get a unified view of the health, performance, and dependencies across the entire system to quickly diagnose issues?

---

### service mesh

- `service mesh`
  - a **dedicated infrastructure layer** that manages safe, reliable, and observable **communication between services** in a microservices application.

- `Data Plane`:
  - A network of **lightweight proxies** (often called `sidecars`, like `Envoy`) runs right alongside each microservice container.
  - **intercept all inbound and outbound** network traffic.
- `Control Plane`:
  - A **central management component** configures the sidecars, enforces policies, updates routing rules, and collects telemetry data.

---

- **Secure Network Connectivity**
  - `service mesh` automates the **security of inter-service communication**.
  - By intercepting all traffic, the `sidecar proxies` can enforce security policies centrally.

- **Service Discovery**
  - Many tools like `Consul` provides a dedicated service discovery feature that **maintains registry with list of IP addresses of all the services**.
    - If a service wants to connect to a messaging service, it can **query the registry** and **find the latest** set of IP addresses for the messaging service.
- **Network Isolation**
  - A service mesh can enable a **zero-trust network model** by allowing you to define fine-grained `access policies` based on service identity, not just network location.
- **Monitoring**
  - Because all service-to-service traffic flows through the sidecar proxies, the service mesh is in a unique position to **generate detailed telemetry data** for the entire application.

- popular service mesh solutions
  - Istio, Consul, Linkerd

---

## Istio

| Important Features         | Description                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------- |
| **Secure by default**      | zero-trust solution based on workload identity, mutual TLS, and strong policy controls. |
| **Increase observability** | generates telemetry; integrates with APM systems                                        |
| **Manage traffic**         | simplifies traffic routing and service-level configuration                              |

- High-Level Architecture
  - `data plane`
    - composed of a set of intelligent proxies (`Envoy`) deployed as `sidecars`.
    - These proxies mediate and **control all network communication** between microservices.
    - c**ollect and report telemetry** on all mesh traffic.
  - `ontrol plane`
    - **manages and configures the proxies** to route traffic

---

### Envoy

- Istio uses an extended version of the `Envoy proxy`.
  - Envoy is a high-performance proxy developed in C++ to **mediate all inbound and outbound traffic** for all services in the service mesh.
- Many built-in features
  - Dynamic service discovery
  - Load balancing
  - TLS termination
  - Health checks
  - Fault injection
  - Rich metrics
- allows you to **add Istio capabilities** to an existing deployment **without** requiring you to rearchitect or rewrite code

---

### Security

- Istiod acts as a `Certificate Authority (CA)` and **generates certificates** to allow secure `mTLS` communication in the `data plane`.

---

### Monitoring

- With Istio, you gain monitoring of the traffic between microservices by default.
- You can use the Istio Dashboard for monitoring your microservices in real time.

---
