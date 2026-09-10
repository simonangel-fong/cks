# CKS: Fundamental - Monolithic vs Microservices

[back](../README.md)

- [CKS: Fundamental - Monolithic vs Microservices](#cks-fundamental---monolithic-vs-microservices)
  - [Monolithic architecture](#monolithic-architecture)
  - [Microservices architecture](#microservices-architecture)

## Monolithic architecture

- `Monolithic architecture`
  - a traditional **software design model** where all parts of an application—such as the user interface, business logic, and data access—are **combined into a single, unified codebase** and **deployed as one single unit**.

- **Key Characteristics**
  - **Single Codebase**:
    - All features and modules live in one place.
  - **Tightly Coupled**:
    - Components depend heavily on each other.
  - **Shared Memory**:
    - Parts talk to each other directly inside the same system process.
  - **Single Deployment**:
    - You must build and release the entire application at once.

- **Pros and Cons**
  - **Pros**:
    - Simpler to build, test, and launch early on; easier to debug; great for small projects or startup MVPs.
  - **Cons**:
    - Harder to scale individual features; small code changes require updating the whole app; if one part crashes, the entire system can go down.

---

## Microservices architecture

- `Microservices architecture`
  - a design approach where a **single** application is built as **a suite of small, independent services** that each run in their own process and **communicate over APIs**.

- **Core Characteristics**
  - **Independent Deployment**:
    - **Each** service can be **updated, built, and deployed** without affecting other parts of the application.
  - **Loose Coupling**:
    - Services are **autonomous** and interact through well-defined **interfaces** like REST APIs.
  - **Decentralized Data**:
    - **Each** microservice typically manages and owns its **own private database or data storage**.
  - **Technology Diversity**:
    - Teams can use different programming languages, frameworks, and technologies for different services.

- **Pros**
  - **Scalability**:
    - Scale only the specific services facing high demand, saving infrastructure costs.
  - **Fault Isolation**:
    - A failure or crash in one service does not automatically bring down the entire application.
  - **Faster Deployment**:
    - Small teams can build, test, and push updates to their services independently.
  - **Tech Flexibility**:
    - Mix and match different programming languages and databases best suited for each job.
- **Cons**
  - **Complexity**:
    - Managing dozens of moving parts, networks, and integrations is highly complex.
  - **Data Consistency**:
    - Syncing data across multiple independent databases is difficult and requires complex patterns.
  - **Testing & Debugging**:
    - Finding the root cause of an error across many distributed networks is tedious.Network Overhead: Constant communication between services over APIs can introduce latency.

---