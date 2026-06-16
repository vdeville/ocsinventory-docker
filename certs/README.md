# TLS certificates

The edge nginx (`frontend` service) terminates TLS with certificates **mounted** from
this directory (never baked into the image). Place two files here:

- `fullchain.pem` — server certificate + intermediate chain
- `privkey.pem`   — matching private key

These filenames are referenced by `frontend/default.conf.template`.

## Production
Use certificates issued by your CA / Let's Encrypt. For Let's Encrypt with
certbot, point/symlink:

```
certs/fullchain.pem -> /etc/letsencrypt/live/<domain>/fullchain.pem
certs/privkey.pem   -> /etc/letsencrypt/live/<domain>/privkey.pem
```

(The nginx config already exposes `/.well-known/acme-challenge/` on port 80 for
http-01 renewals if you add a certbot container.)

## Local testing (self-signed)
```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/privkey.pem -out certs/fullchain.pem \
  -days 365 -subj "/CN=localhost"
```

> `*.pem` files in this directory are gitignored.
