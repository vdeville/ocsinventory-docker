---
description: "Upgrade the OCS Inventory Docker stack safely: forward-only migrations, what makes it safe, and the rollback plan."
---

# Upgrading

Upgrades are designed to be safe and boring. Migrations are applied idempotently
before the app starts, and the database volume and `SECRET_KEY` are preserved —
so sessions and API tokens survive.

:::tip Back up first
Snapshot the database **before** bumping the version — a migration moves the
schema forward and is not undone by downgrading the image, so a backup is your
only guaranteed way back. See [Backups & logs](backups-logs.md).
:::

## With prebuilt images

Bump the version refs and redeploy:

```bash
# .env
OCS_BACKEND_REF=3.0.0-rc2
OCS_FRONTEND_REF=3.0.0-rc2
```
```bash
docker compose pull
docker compose up -d
docker compose logs ocs-init        # new migrations applied, exit 0
```

(The target version must be published — see [Releasing a version](../developer/releasing.md).)

## What makes it safe

* `ocs-init` runs `migrate` (never `makemigrations`). New migrations shipped in
  the release apply automatically; re-running on an up-to-date database is a
  no-op.
* `backend` and `automation` start **only after** `ocs-init` succeeds
  (`service_completed_successfully`) — no migration races.
* `SECRET_KEY` comes from `.env` and does not change, so existing sessions and
  tokens keep working.
* The `db` and `media` volumes are untouched by an image change.

## During the switch

When the `backend` container is recreated its IP changes; nginx re-resolves the
upstream at runtime (Docker DNS), so there is no lingering `502`. Expect a brief
unavailability while the new backend boots and `ocs-init` finishes.

## Rollback

Downgrading the image **does not undo migrations**. `manage.py migrate` only rolls
*forward* — `ocs-init` never un-applies migrations the database already has. So
pointing the refs back and running `up -d` leaves the schema at the **newer**
version; the older code then runs against that forward schema, which works only if
the new migrations happened to be backward-compatible. It is **not** a real
rollback.

For a reliable rollback, restore the database from a backup taken **before** the
upgrade, and set the refs back:

```bash
# 1. put the previous OCS_BACKEND_REF / OCS_FRONTEND_REF back in .env
docker compose down
# 2. restore the ocs-pgdata volume from your pre-upgrade dump
#    (see Backups & logs)
docker compose up -d
```

Advanced alternative: if the new migrations are reversible, un-apply them
**while the new version is still running** (so the migration files exist), then
downgrade:

```bash
docker compose exec backend python manage.py migrate <app> <previous_migration>
```

Restoring a backup is the safer, predictable path.
