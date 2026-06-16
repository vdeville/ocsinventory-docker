---
description: "Troubleshoot the OCS Inventory Docker stack — 502 errors, static 404s, admin login, stuck migrations, and agent submissions."
---

# Troubleshooting

## The app refuses to start: "SECRET_KEY ... required"

`DEBUG=False` (the default) requires a `SECRET_KEY`. Set a stable one in `.env`:

```bash
openssl rand -hex 50
```

## `502 Bad Gateway` on `/api/...`

* Right after `up`, the backend may still be starting (it waits for `ocs-init`).
  Check `docker compose logs backend` and `docker compose logs ocs-init`.
* If it persists, verify `BACKEND_UPSTREAM` (default `backend:8000`) and that the
  `backend` service is healthy (`docker compose ps`).

## `404` on `/api/static/...`

Static is served by WhiteNoise behind the stripped `/api` prefix. This works out
of the box; if you customized `API_BASE_PATH`, recreate **both** `frontend` and
`backend` so the prefix stays in sync (`docker compose up -d frontend backend`).

## A config change didn't take effect

`docker compose restart` reuses the container's existing environment. Use
`docker compose up -d <service>` to **recreate** with the new `.env` values.

## UI loads but can't reach the API

Check `https://<host>/front/config/config.json` — `BACKEND_API_ROUTE` must be the
correct public API URL. It is derived from `PUBLIC_URL` + `API_BASE_PATH`; make
sure `PUBLIC_URL` is right (including a non-standard port if any).

## Login as `admin` fails

* On a fresh database, the password is `OCS_ADMIN_PASSWORD` (or `admin` if it was
  empty at first init).
* If it was changed in the UI, the bootstrap no longer overrides it. Reset:

  ```bash
  docker compose exec backend python manage.py changepassword admin
  ```

## Agents can't submit inventories

* Point agents at `https://<host>/api/asset/legacy/` (v2) or
  `/api/asset/collection/`.
* If you changed `API_BASE_PATH`, agents must be reconfigured to the new path.
* Large inventories: the edge allows 200 MB bodies; a reverse proxy in front of
  this stack must allow at least as much.

## Migrations seem stuck

`backend`/`automation` wait for `ocs-init` to finish (up to
`MIGRATE_WAIT_TIMEOUT`, default 300 s). Inspect `docker compose logs ocs-init`
for the migration output or errors (e.g. the DB not reachable →
`DB_WAIT_TIMEOUT`).

## Host networking

This stack uses bridge networking. On Docker Desktop (macOS/Windows) host
networking is emulated and host ports are not exposed like on Linux — stay on
bridge networking there.
