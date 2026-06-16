---
description: "Back up and restore the PostgreSQL and media volumes of the OCS Inventory Docker stack, and read service logs."
---

# Backups & logs

## What to back up

| Volume | Contents | Critical? |
|--------|----------|:---------:|
| `ocs-pgdata` | PostgreSQL data (all inventory, config, users) | ✅ yes |
| `ocs-media` | uploaded files (deployment packages, filemanager) | ✅ yes |

Static files are baked into the image (not a volume) and need no backup.
`SECRET_KEY` lives in `.env` — back up `.env` and your `certs/` too.

:::info Run from the compose directory & check your volume names
Run these commands from the directory that holds your `compose.yaml` and `.env`,
so `docker compose` targets this project. Docker prefixes the **named volumes**
with the Compose project name (by default the directory name) — e.g. a project in
`/opt/ocsinventory` exposes `ocsinventory_ocs-pgdata` and `ocsinventory_ocs-media`.
List the real names with `docker volume ls` and adapt the commands accordingly.
:::

## Database backup / restore

Logical dump (recommended):

```bash
# Backup
docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > ocs-$(date +%F).sql

# Restore (into an empty database)
docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" < ocs-YYYY-MM-DD.sql
```

(`DB_USER` / `DB_NAME` are the values from your `.env`.)

## Media backup

```bash
# Replace <project>_ocs-media with your actual volume name (docker volume ls)
docker run --rm -v <project>_ocs-media:/data -v "$PWD":/backup alpine \
  tar czf /backup/ocs-media-$(date +%F).tgz -C /data .
```

`<project>` is the Compose project name (the directory name by default), so the
volume is e.g. `ocsinventory_ocs-media` — see the note above.

## Logs

All services log to **stdout/stderr**, captured by Docker:

```bash
docker compose logs -f backend            # API (gunicorn + Django)
docker compose logs -f automation         # scheduler
docker compose logs ocs-init              # migrations (one-shot)
docker compose logs -f frontend                # nginx
```

`LOG_LEVEL` controls the Django root level; `GUNICORN_LOG_LEVEL` the gunicorn
level.

## Healthchecks

| Service | Check |
|---------|-------|
| `db` | `pg_isready` |
| `backend` | `curl http://localhost:8000/api-check/` |
| `frontend` | none (stateless) |
| `automation` | none (no server; it runs the scheduler loop) |

```bash
docker compose ps          # shows health status per service
```
