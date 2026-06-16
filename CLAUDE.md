# CLAUDE.md

Guidance for AI coding agents and contributors working in this repository.
This file captures the conventions, architecture, and **hard invariants** of the project — read it before making changes.
For end-user and full reference documentation, see the docs site (built from `docs/`).

## What this is

A clean, production-grade Docker **stack** and **images** for **OCS Inventory 3.0**:

- **backend** — Django 6 REST API (gunicorn + WhiteNoise)
- **frontend** — Vue 3 / Vite SPA served by an nginx edge
- **database** — PostgreSQL

It is designed to be secure and **upgrade-friendly**: a version bump replays `migrate` while preserving data, `SECRET_KEY`, and sessions.

## Repository layout

```
compose.yaml          production stack (prebuilt GHCR images, no build)
compose.dev.yaml      dev override: build images from source
.env.example          configuration template (copy to .env)
versions.json         build manifest (one entry per OCS version)
backend/              backend image: Dockerfile, entrypoint, settings overlay, patches/<ref>/
frontend/             frontend image: Dockerfile, nginx template, entrypoint, patches/<ref>/
certs/                TLS certs are mounted from here (gitignored, never baked)
examples/             standalone compose.yaml + .env.example bundle
docs/                 documentation (Markdown)
website/              Docusaurus site that renders docs/ (deployed to GitHub Pages)
.github/workflows/    CI: ci.yml, build-and-push.yml, docs.yml
```

## Architecture (key concepts)

- **Single hostname**: `/front/` serves the UI, `/api/` serves the backend and agents — same origin, so **no CORS** is needed.
- **Services**: `db` · `ocs-init` (one-shot: runs migrations, then exits) · `backend` (gunicorn) · `automation` (scheduler loop) · `frontend` (nginx edge: TLS, serves the SPA, reverse-proxies `/api/`).
- **One backend image** is shared by `backend` / `ocs-init` / `automation`, differentiated by the **`OCS_ROLE`** env var (`init` / `web` / `automation`).
- `ocs-init` applies migrations exactly once; `backend` and `automation` wait for it via `service_completed_successfully`.
- **Runtime-configurable base paths**: the frontend image is built with a sentinel base `/__OCS_BASE__/`; the entrypoint materializes the SPA and renders the nginx config at container start (envsubst), driven by `FRONTEND_BASE_PATH` and `API_BASE_PATH`. No rebuild is needed to change a path.
- **Settings overlay**: production settings live in `backend/overlay/.../settings_docker.py`, which does `from .settings import *` and only overrides what is needed. The upstream `settings.py` is never modified.
- Agent endpoints: `/api/asset/legacy/` (XML+zlib) and `/api/asset/collection/`.

## Invariants — do not break these

1. **`frontend` is the SPA/nginx service; `OCS_ROLE=web` is the backend's gunicorn role.** They are unrelated — never rename or conflate `OCS_ROLE=web` with the frontend.
2. **Never modify the upstream `settings.py`.** All customization goes through the `settings_docker.py` overlay.
3. **Migrations are forward-only.** Use `migrate` only — never run `makemigrations` at runtime. Downgrading a version requires restoring a database backup (`migrate` does not roll back).
4. **`SECRET_KEY` must stay stable** across restarts and upgrades, or sessions and tokens are invalidated.
5. **No `container_name`** in the compose files (it prevents scaling / multiple instances; Compose already names containers).
6. **`compose.yaml` stays build-free** (prod = pull prebuilt GHCR images). Building from source lives only in `compose.dev.yaml`.
7. **TLS certificates are mounted, never baked into images.** `.env` and `certs/*` are gitignored — never commit them.
8. **`OCS_ADMIN_PASSWORD` is bootstrap-only**: applied only while the `admin` account still has its default password, never overwritten afterwards.
9. **PostgreSQL only** — the DB engine is pinned in the overlay; `DB_ENGINE` is not exposed.
10. **Changing an env var = recreate, not restart**: use `docker compose up -d <service>` (restart reuses the old environment).
11. **Keep `examples/` in sync** with the root `compose.yaml` and `.env.example` — they are intentional duplicates (the bundle must stay self-contained and downloadable; a symlink would break the raw download).
12. **Code comments: one sentence per line** (no mid-sentence wrapping, even past 80 columns). Applies to Dockerfiles, shell scripts, compose files, `.env.example`, settings, and workflows. Markdown prose is exempt.

## Development

```bash
# 1. Configure
cp .env.example .env          # set SECRET_KEY (openssl rand -hex 50), DB_PASSWORD, etc.

# 2. Local TLS (self-signed, for testing)
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/privkey.pem -out certs/fullchain.pem -days 365 -subj "/CN=localhost"

# 3. Build from source and run
docker compose -f compose.yaml -f compose.dev.yaml build
docker compose -f compose.yaml -f compose.dev.yaml up -d
```

Smoke test (with `PUBLIC_URL=https://localhost` and self-signed certs, use `curl -k`):

- `GET /` → `302` to `/front/`
- `GET /api/api-check/` → `200`
- `GET /front/` → `200`, and `GET /front/config/config.json` → `{"BACKEND_API_ROUTE":"https://localhost/api/"}`
- `GET /api/static/...` → `200` (served by WhiteNoise behind the stripped `/api` prefix)
- the SPA index references assets under `/front/` (validates the runtime base path)

## Versioning & releases

- **`versions.json`** lists each OCS version with `version`, `backend_ref`, `frontend_ref` (upstream git tags). There is no `latest` field.
- The Dockerfiles are **generic and parameterized** by `OCS_*_REF` — there is no per-version Dockerfile duplication.
- **Builds are triggered by pushing a git tag** equal to a `version` (e.g. `3.0.0-rc1`). Only the tagged version is built and published as `:<version>`. Editing `versions.json` alone does not build anything.
- **Optional per-version fields** (no Dockerfile fork needed): `backend_extra_build_apt`, `backend_extra_runtime_apt`, `backend_extra_pip`, and `backend_dockerfile` / `frontend_dockerfile` (custom Dockerfile, last resort).
- **Source patches, no config**: drop `.patch` files in `backend/patches/<backend_ref>/` or `frontend/patches/<frontend_ref>/`; they are applied in filename order (prefix `000-`, `010-`). A missing directory means an unmodified build.

## CI/CD (`.github/workflows/`)

- **`ci.yml`** — on pull requests and pushes to `main`: hadolint, ShellCheck, `docker compose config`, and a build of both images (no push). **CI must pass before merge.**
- **`build-and-push.yml`** — on a version tag (or manual dispatch): builds the single tagged version multi-arch (amd64/arm64) and pushes to GHCR (`ghcr.io/<owner>/ocsinventory-{backend,frontend}`; forks publish under their own owner).
- **`docs.yml`** — on changes under `docs/` or `website/`: builds the Docusaurus site and deploys to GitHub Pages.

## Documentation

- Markdown lives in `docs/`; the Docusaurus site lives in `website/`.
- `docs/getting-started.mdx` imports `examples/compose.yaml` and `examples/.env.example` via `raw-loader` (single source — no copy-pasted snippets).
- Preview: `cd website && npm run start`. Build (also checks for broken links): `npm run build`.
- **Keep docs in sync with behavior**: a change to env vars, services, or the build flow should update the relevant page under `docs/`.

## Contributing notes

- Prefer **clean, idiomatic** solutions over workarounds; when a fix belongs upstream (e.g. the frontend base-path support), submit it upstream and apply it here as a versioned patch until merged.
- Make sure `ci.yml` passes locally before opening a PR (lint + compose config + build).
- Touch the upstream sources only through the documented seams: the settings overlay, the entrypoints, the nginx template, and the `patches/<ref>/` directories.
