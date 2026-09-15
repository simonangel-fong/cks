# Practices - runtime & image

[Back](../README.md)

- [Practices - runtime \& image](#practices---runtime--image)
  - [image: use digest](#image-use-digest)
  - [image: deploy use digest](#image-deploy-use-digest)
  - [Dockerfile](#dockerfile)
  - [Dockfile: secret](#dockfile-secret)

---

## image: use digest

- task:
  - create a pod named `crazy-pod` using `nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515`

---

- solution

```sh
k run crazy-pod --image=nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515

 k describe po crazy-pod | grep -i "image:"
    # Image:          nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515
```

---

## image: deploy use digest

- task:
  - convert the existing deplyment `crazy-deployment` to use the image digest `nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515`

---

- setup env

```sh
k create deploy crazy-deployment --image=nginx
```

---

- solution

```sh
k edit deploy crazy-deployment
      - image: nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515

k rollout restart deploy crazy-deployment

# confirm
k describe po | grep -i image:
    # Image:          nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515
    # Image:          nginx@sha256:14cf3fc577e44ed7a7fbdb7eb9fdae07577d532f714d24517c2df90cd9c5a515

```

---

## Dockerfile

- task:
  - Dockerfile is under `/opt/cks/Dockerfile`
  - build an image name `base-image`
  - Run a container named `c1`
  - Check the user the `sleep` process is running.
  - output the username in the file `/opt/cks/username`
  - remove the container

---

- setup:

```sh
sudo mkdir -p /opt/cks

sudo tee /opt/cks/Dockerfile >/dev/null <<'EOF'
FROM alpine:3.20

RUN adduser -D -u 1001 appuser

USER appuser

CMD ["sleep", "3600"]
EOF
```

---

- solution

```sh
su -
cd /opt/cks
ls
# Dockerfile

docker build -t base-image .

docker run -d --name c1 base-image
# a34975de507af06592425a1e1b62f084ed8cc55c839ef6b86dddd1eac62766be

docker exec c1 ps
# PID   USER     TIME  COMMAND
#     1 appuser   0:00 sleep 3600
#    22 appuser   0:00 ps

echo appuser > /opt/cks/username
cat /opt/cks/username
# appuser

docker rm -f  c1
# c1
```

---

## Dockfile: secret

- context
  - dockerfile at /opt/cks/secret/Dockerfile
  - a simple container that tries to connect wih an imaginary api with a secret token, getting 404, which is ok.
- Task: update the Dockfile
  - use the pecific version `20.04` for base image
  - remove layer caching issues with apt-get
  - remove the hardcoded secret value `2fba3514-42f8-4de7-be1a-54e0f7c86547`
  - secret should be passed into the container during runtime as env varable `TOKEN`
  - make it impossible to `docker exec` or `kubectl exec` into the contaiern using `bash`

---

- setup env:

```sh
sudo mkdir -p /opt/cks/secret

sudo tee /opt/cks/secret/Dockerfile >/dev/null <<'EOF'
FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y curl

CMD ["sh", "-c", "curl -H \"Authorization: Bearer 2fba3514-42f8-4de7-be1a-54e0f7c86547\" https://httpbin.org/status/404; sleep infinity"]
EOF
```

---

- solution

```sh
cd /opt/cks/secret

cp Dockerfile Dockerfile.bak
# harden the dockfile
vi Dockerfile
# FROM ubuntu:20.04

# RUN apt-get update && apt-get install -y curl
# RUN rm /usr/bin/bash

# CMD ["sh", "-c", "curl -H \"Authorization: Bearer $TOKEN\" https://httpbin.org/status/404; sleep infinity"]

# build
docker build -t app .
# run
docker run -d --name app -e TOKEN="2fba3514-42f8-4de7-be1a-54e0f7c86547" app
# 97407669a7f515cafbdd0a9401098354284401436fde408bb9ecf805437c09ea

docker exec app bash
# OCI runtime exec failed: exec failed: unable to start container process: exec: "bash": executable file not found in $PATH
```