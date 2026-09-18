# Practices - Ingress

[Back](../README.md)

- [Practices - Ingress](#practices---ingress)
  - [Ingress: tls](#ingress-tls)

---

- Ingress with TLS
  - Be familiar with the steps required to set up Ingress with TLS.
  - Be familiar with ssl-redirect annotation for HTTP to HTTPS
    - ref: https://kubernetes.github.io/ingress-nginx/examples/rewrite/

## Ingress: tls

- task:
  - create ingress with tls
    - host: example.com
    - /backend: backend svc, port 80
    - /frontend: frontend svc, port 80
    - redirect http to https

- setup env

```sh
k run backend --image=nginx
k expose po backend --name backend --port 80 --target-port 80
k run frontend --image=nginx
k expose po frontend --name frontend --port 80 --target-port 80
```

- solution

```yaml
# ingress-tls.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - "example.com"
      secretName: secret-tls
  rules:
    - host: "example.com"
      http:
        paths:
          - path: /frontend
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
          - path: /backend
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 80
```

```sh
# create key and crt
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=example.com"

kubectl create secret tls secret-tls --cert=tls.crt --key=tls.key

kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       3d2h

k apply -f ingress-tls.yaml
# ingress.networking.k8s.io/ingress-tls created

```

---
