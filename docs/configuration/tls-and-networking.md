---
description: "Configure TLS certificates, ports, the API reverse proxy, DNS resolver, and networking for the OCS Inventory Docker stack."
---

# TLS & networking

## Certificates

The `frontend` (nginx) service terminates TLS with certificates **mounted** from
`certs/` — they are never baked into the image:

* `certs/fullchain.pem` — server certificate + intermediate chain
* `certs/privkey.pem` — matching private key

### Let's Encrypt

Point or symlink the files at your live certificates:

```
certs/fullchain.pem -> /etc/letsencrypt/live/<domain>/fullchain.pem
certs/privkey.pem   -> /etc/letsencrypt/live/<domain>/privkey.pem
```

The nginx config exposes `/.well-known/acme-challenge/` on port 80 for http-01
renewals if you add a certbot container.

### Self-signed (local test)

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/privkey.pem -out certs/fullchain.pem -days 365 -subj "/CN=localhost"
```

## Ports

`HTTP_PORT` (default 80) and `HTTPS_PORT` (default 443) are both the **port nginx
listens on** and the **published host port**.

```bash
# .env — serve on non-standard ports
HTTP_PORT=8080
HTTPS_PORT=8443
PUBLIC_URL=https://ocs.example.com:8443
```

The HTTP→HTTPS redirect uses `HTTPS_PORT` (the port is included only when it is
not 443). With a non-standard HTTPS port, include it in `PUBLIC_URL` so the
derived `BACKEND_API_ROUTE` and the runtime `config.json` point at the right
port.

## API upstream & DNS resolver

The `frontend` service reverse-proxies the API to `BACKEND_UPSTREAM` (default
`backend:8000`). It uses a DNS resolver (`BACKEND_RESOLVER`, default
`127.0.0.11`, Docker's embedded DNS) to **re-resolve** the upstream at request
time — so the `backend` container can be recreated (e.g. during an upgrade)
without nginx returning `502` from a stale cached IP.

| Scenario | `BACKEND_UPSTREAM` | `BACKEND_RESOLVER` |
|----------|--------------------|--------------------|
| Default (Docker network) | `backend:8000` | `127.0.0.11` |
| Static address (no DNS) | e.g. `10.0.0.5:8000` | _(empty)_ |

## Behind an external reverse proxy / load balancer

If you terminate TLS upstream (another nginx, Traefik, a cloud LB), you can:

* keep the `frontend` service and let it re-terminate TLS, or
* front the `frontend` service directly (it already sets `X-Forwarded-Proto` to the
  backend; the backend trusts it via `SECURE_PROXY_SSL_HEADER`).

Set `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` to the public hostname in all
cases.

## Media

Uploaded files (deployment packages, filemanager) live on the `ocs-media`
volume. `frontend` mounts it read-only and serves `/<api>/media/` directly from it;
`backend` mounts it read-write.

## Host networking

This stack runs on **bridge** networking. If you need `network_mode: host`, the
configuration hooks are already in place (`BACKEND_UPSTREAM`, `BACKEND_RESOLVER`,
and variable listen ports), so it can be added as an opt-in compose override
without changing the images. On Docker Desktop (macOS/Windows), host networking
is emulated and host ports aren't exposed like on Linux — use bridge there.
