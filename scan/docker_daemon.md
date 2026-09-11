# CKS: secure docker daemon

[Back](../README.md)

- [CKS: Trivy](#cks-trivy)
  - [Container Security Scanning](#container-security-scanning)

---

## secure docker daemon

- In most organizations, `Docker daemon` runs with **root privileges**
  - any user with access to the daemon can potentially gain **elevated privileges** on the host system

- **Removing Users from Docker Group**
  - Users in the Docker `group` effectively **have root privileges** on the host system, as they can create containers that mount sensitive host directories.
    - `cat /etc/group | grep docker`

- **Deny Traffic to Docker Daemon**
  - If the daemon is exposed over TCP (tcp://0.0.0.0:2375 or tcp://0.0.0.0:2376), it becomes a prime target for remote attacks
  - ports:
    - `2375`: Unencrypted (HTTP) communication.
    - `2376`: Encrypted (HTTPS/TLS) communication.
  - check port: `netstat -tnpl | grep -E "2375|2376"`

---

## Lab: add user to docker group

```sh
# install docker

# create docker-user
# add docker-user to docker group
# spin up and exec a privilege container with docker-user
# create attacker user via privilege contianer and add it to root group
# login as attacker
# modify files as privilege user with attacker user.

```

---

## Lab: expose docker daemon over TCP

```sh
# enable docker remote connection, docker.service file
# test, ip;2375/version

# create a regular test-user, try to create container, permission deny
# attacker create and start privilege container via ip

```

---

## Secure Docker daemon

- Simple config: Use **flags** with `dockerd`
- Complex config: Use a `JSON` configuration file (preferred)

- json conf file path

| OS and Configuration | Description                              |
| -------------------- | ---------------------------------------- |
| Linux, regular setup | /etc/docker/daemon.json                  |
| Windows              | C:\ProgramData\docker\config\daemon.json |

---

## Secure Docker Daemon Socket

- If you need Docker to be reachable through HTTP, you can **enable** `TLS (HTTPS)` and allow trusted connections through certificate based authentication

---

### Lab:

- ref: https://github.com/zealvora/certified-kubernetes-security-specialist/blob/main/domain-5-supply-chain-security/docker-tls.md
