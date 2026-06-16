# OCS Inventory 3.0 — Docker production stack

A clean, secure, upgrade-friendly Docker deployment of **OCS Inventory 3.0**
(Django backend + Vue/Vite frontend + PostgreSQL), behind a single hostname.

```
https://ocs.example.com/front/...   → Vue SPA (UI)
https://ocs.example.com/api/...     → Django REST API + agent endpoints
```

## 📖 Documentation

Full docs (Docusaurus, deployed to GitHub Pages):
**https://vdeville.github.io/ocsinventory-docker/** — or browse [`docs/`](docs/).

* [Getting started](docs/getting-started.mdx) — deploy in a few commands
* [Configuration](docs/configuration/) — every environment variable explained
* [Architecture](docs/architecture.md) — how the stack works
* [Operations](docs/operations/) — upgrade, admin & agents, backups
* [Developer docs](docs/developer/) — versions, patches, CI/CD

## Architecture

| Service      | Role |
|--------------|------|
| `db`         | PostgreSQL 16 (named volume `ocs-pgdata`). |
| `ocs-init`   | One-shot: applies migrations (+ optional admin password), then exits. Gates the others. |
| `backend`    | Django API via gunicorn (`:8000`, internal). Static baked at build, served by WhiteNoise. |
| `automation` | Same image as `backend`, runs `manage.py automation` on a loop. |
| `frontend`        | nginx edge: TLS, serves the SPA, reverse-proxies the API and media. |

`backend`, `ocs-init` and `automation` are the **same image**, selected by
`OCS_ROLE`. Images are built from pinned upstream tags and published to GHCR.

## Quick start

```bash
cp .env.example .env
# Set PUBLIC_URL, SECRET_KEY (openssl rand -hex 50), DB_PASSWORD,
# OCS_ADMIN_PASSWORD, ALLOWED_HOSTS, CSRF_TRUSTED_ORIGINS.
# Put TLS certs in certs/ (fullchain.pem, privkey.pem).

docker compose pull
docker compose up -d
```

Then open `https://<your-host>/front/ocsreports` and log in as `admin`.
See [Getting started](docs/getting-started.mdx) for the full walk-through, or grab
the standalone bundle in [`examples/`](examples/).

Build from source instead of pulling:

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

## Layout

```
compose.yaml          production stack (prebuilt GHCR images)
compose.dev.yaml      dev override: build images from source
.env.example          configuration template
versions.json         build manifest (OCS versions)
examples/             standalone compose.yaml + .env.example bundle
backend/   Dockerfile · entrypoint.sh · gunicorn.conf.py · overlay/settings_docker.py · patches/<ref>/
frontend/       Dockerfile · default.conf.template · entrypoint.sh · patches/<ref>/
certs/     mount fullchain.pem / privkey.pem here (gitignored)
docs/      documentation (Markdown) · website/ — Docusaurus site
.github/workflows/    CI (lint + build), image build/push to GHCR, docs to Pages
```

## License

The images bundle OCS Inventory, which is licensed under **GPL-3.0**.
