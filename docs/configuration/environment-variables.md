---
description: "Complete environment variable reference for the OCS Inventory Docker stack — URLs, TLS, database, admin, gunicorn, and image versions."
---

# Environment variables

The complete reference. Variables marked **Required** must be set for a
production start. Variables marked _derived_ are computed when left empty.

> Tip: anything not in `.env.example` has a sensible default baked into the
> compose file or the images — you only add it to `.env` to override.

## Public access & URLs

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `PUBLIC_URL` | `https://ocs.example.com` | ✅ | Public base URL of the stack (scheme + host, optionally `:port`). Used to derive `BACKEND_API_ROUTE` and `FRONTEND_REDIRECT`. |
| `FRONTEND_BASE_PATH` | `/front/` | – | URL sub-path the UI is served under. Non-root, slash-wrapped. Runtime setting. |
| `API_BASE_PATH` | `/api/` | – | URL sub-path the API (and agents) are served under. Drives nginx routing **and** the backend `FORCE_SCRIPT_NAME`. Must differ from `FRONTEND_BASE_PATH`. |
| `BACKEND_API_ROUTE` | _derived_ | – | Absolute URL the browser uses to reach the API. Empty → `PUBLIC_URL` + `API_BASE_PATH`. Set explicitly only for split-origin (API on another host). |

See [Base paths](base-paths.md).

## TLS & ports

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `HTTP_PORT` | `80` | – | Port nginx listens on for HTTP (redirects to HTTPS). Also the published host port. |
| `HTTPS_PORT` | `443` | – | Port nginx listens on for HTTPS. Used to build the HTTP→HTTPS redirect (the port is included only when non-default). For a non-standard port, put it in `PUBLIC_URL` too. |

Certificates are mounted from `certs/` (`fullchain.pem`, `privkey.pem`), never
baked. See [TLS & networking](tls-and-networking.md).

## Django security

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `SECRET_KEY` | – | ✅ | Django secret key. **Keep it stable** across upgrades or sessions/tokens are invalidated. The app refuses to start without it when `DEBUG=False`. |
| `DEBUG` | `False` | – | Enable Django debug mode. Accepts `1/true/yes/on`. Keep `False` in production. |
| `ALLOWED_HOSTS` | `*` | recommended | Comma-separated hostnames Django will serve. Set to your hostname(s). |
| `CSRF_TRUSTED_ORIGINS` | _(empty)_ | recommended | Comma-separated origins (scheme + host) trusted for CSRF / OIDC / CAS flows. |
| `FRONTEND_REDIRECT` | _derived_ | – | **SSO only** (CAS/OIDC): URL the backend redirects the browser to after a login callback, with the auth token in the URL fragment. Empty → `PUBLIC_URL` + `FRONTEND_BASE_PATH` + `ocsreports`. Unused for local login. |
| `LOG_LEVEL` | `INFO` | – | Django root log level (logs go to stdout). |

## Database (PostgreSQL)

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `DB_NAME` | `ocsdb` | ✅ | Database name (also creates it in the `db` service). |
| `DB_USER` | `ocsuser` | ✅ | Database user. |
| `DB_PASSWORD` | `change-me` | ✅ | Database password — set a strong value. |
| `DB_HOST` | `db` | – | Database host. Defaults to the `db` service name. |
| `DB_PORT` | `5432` | – | Database port. |

> Only PostgreSQL is supported; the engine is pinned in the image and
> `DB_ENGINE` is not exposed. (MySQL/MariaDB may be added later.)

## First admin

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `OCS_ADMIN_PASSWORD` | `change-me` | recommended | Bootstrap password for the `admin` superuser. Applied **only while the account still has its default password**; once changed (here or via the UI) it is never touched again. Rotate later via the UI or `manage.py changepassword`. |

See [Admin, auth & agents](../operations/admin-auth-agents.md).

## Automation (scheduler)

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `AUTOMATION_INTERVAL` | `60` (compose) / `300` (in `.env.example`) | – | Seconds between `manage.py automation` runs in the `automation` service. |

## API proxy / networking (advanced)

These have working defaults in the compose file; override only for non-standard
networking.

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `BACKEND_UPSTREAM` | `backend:8000` | – | `host:port` the `frontend` service proxies the API to. |
| `BACKEND_RESOLVER` | `127.0.0.11` | – | DNS resolver nginx uses to re-resolve the upstream at runtime (Docker embedded DNS), so the backend can be recreated without a 502. Set empty to disable runtime DNS resolution (static address). |

## CORS (advanced)

Front and API share one origin by default, so CORS is off. For split-origin:

| Variable | Default | Required | Description |
|----------|---------|:--------:|-------------|
| `CORS_ALLOW_ALL_ORIGINS` | `False` | – | Allow all origins (not recommended). |
| `CORS_ALLOWED_ORIGINS` | _(empty)_ | – | Comma-separated allowed origins. |
| `SECURE_SSL_REDIRECT` | `False` | – | Let Django force HTTPS. Off by default (TLS is handled by the nginx edge). |
| `FORCE_SCRIPT_NAME` | _derived from `API_BASE_PATH`_ | – | Sub-path Django mounts under. Normally derived; kept for backward compatibility. |

## Gunicorn tuning (advanced)

Read by `backend/gunicorn.conf.py`.

| Variable | Default | Description |
|----------|---------|-------------|
| `GUNICORN_WORKERS` | `(2 × CPU) + 1` | Worker processes. |
| `GUNICORN_THREADS` | `1` | Threads per worker. |
| `GUNICORN_TIMEOUT` | `120` | Worker timeout (s) — agent inventories are zlib XML and take time to parse. |
| `GUNICORN_MAX_REQUESTS` | `1000` | Recycle a worker after N requests (bounds memory). |
| `GUNICORN_MAX_REQUESTS_JITTER` | `100` | Random jitter added to the above. |
| `GUNICORN_LOG_LEVEL` | `info` | Gunicorn log level. |
| `GUNICORN_FORWARDED_ALLOW_IPS` | `*` | IPs allowed to set `X-Forwarded-*` (trusted internal network). |

## Image version

Selects which published image is pulled and run; bump to upgrade (see
[Upgrading](../operations/upgrading.md)).

| Variable | Default | Description |
|----------|---------|-------------|
| `OCS_BACKEND_REF` | `3.0.0-rc1` | OCS backend version — the image tag pulled (`ghcr.io/…/ocsinventory-backend:<ref>`). |
| `OCS_FRONTEND_REF` | `3.0.0-rc1` | OCS frontend version — the image tag pulled. |

> Build-time-only arguments (extra packages, pinned tool versions, custom
> Dockerfile) live in the developer docs — see
> [Build arguments](../developer/layout.md).

## Internal / runtime control

Set automatically by compose or the entrypoints; rarely set by hand.

| Variable | Default | Description |
|----------|---------|-------------|
| `OCS_ROLE` | `web` | Selects the backend image behaviour: `init` (migrate then exit), `web` (gunicorn), `automation` (scheduler loop). Set per service in compose. |
| `DB_WAIT_TIMEOUT` | `60` | Seconds the entrypoint waits for the database before failing. |
| `MIGRATE_WAIT_TIMEOUT` | `300` | Seconds `web`/`automation` wait for migrations to be applied by `ocs-init`. |
