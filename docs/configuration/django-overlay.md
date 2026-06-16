---
description: "How the Dockerized OCS Inventory backend overrides Django settings through a production overlay, without touching upstream code."
---

# Django settings overlay

The upstream Django settings are used **unmodified**. Production tweaks live in a
small overlay shipped alongside them and selected with
`DJANGO_SETTINGS_MODULE=ocsinventory_backend.settings_docker`:

```
backend/overlay/ocsinventory_backend/settings_docker.py
```

It does `from .settings import *` and then overrides only what a containerized,
reverse-proxied deployment needs. Here is what it changes and why.

## Security

* `DEBUG` — parsed robustly from the env (`1/true/yes/on`); defaults to `False`.
* The app **refuses to start** without a `SECRET_KEY` when `DEBUG=False`.
* `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` — from env (comma-separated).
* `SECURE_SSL_REDIRECT` — off by default (TLS is handled by the nginx edge).

## Reverse-proxy / sub-path mounting

* `FORCE_SCRIPT_NAME` — derived from `API_BASE_PATH` (e.g. `/api`). nginx strips
  the prefix before proxying; this makes Django regenerate prefixed URLs.
* `USE_X_FORWARDED_HOST = True` and
  `SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")` — trust the
  edge's forwarded headers.
* `STATIC_URL` / `MEDIA_URL` — prefixed with the API base (`/api/static/`,
  `/api/media/`).

## Static files (WhiteNoise)

* WhiteNoise middleware is inserted right after `SecurityMiddleware`.
* `STORAGES["staticfiles"]` uses
  `whitenoise.storage.CompressedManifestStaticFilesStorage` (hashed,
  pre-compressed assets).
* `WHITENOISE_STATIC_PREFIX = "/static/"` — because nginx strips `/api`, the app
  receives `/static/...` while `STATIC_URL` keeps the `/api` prefix for URL
  generation. This tells WhiteNoise to match the **stripped** path it actually
  receives.

Static files are collected into the image at **build time**, so every container
has them and `ocs-init` only handles the database.

## Database

* The engine is pinned to `django.db.backends.postgresql` (psycopg2 is the only
  driver installed); `DB_ENGINE` is not exposed. Connection details come from
  the `DB_*` env vars (inherited from the upstream settings).

## Logging

* `LOGGING` is replaced with a single console handler at `LOG_LEVEL`, so logs go
  to stdout/stderr and are captured by `docker logs` (upstream uses rotating
  files).

## CORS

* `CORS_ALLOW_ALL_ORIGINS` off by default and `CORS_ALLOWED_ORIGINS` from env —
  not needed for the single-origin topology, kept for split-origin.

## Frontend redirect (SSO)

* `FRONTEND_REDIRECT` — explicit value wins; otherwise derived from
  `PUBLIC_URL` + `FRONTEND_BASE_PATH` + `ocsreports`; empty when `PUBLIC_URL` is
  unset (the SSO redirect is then simply disabled). See
  [Admin, auth & agents](../operations/admin-auth-agents.md).
