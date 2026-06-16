---
description: "Serve the OCS Inventory UI and API under custom URL sub-paths, configured at runtime without rebuilding the images."
---

# Base paths (UI & API)

Both sub-paths are chosen at **container start**, not baked into the image. The
`frontend` entrypoint re-materializes the SPA under its segment, rebases the assets,
and renders the nginx config from the same variables — so assets, routing and the
backend prefix always stay in sync.

## UI base path — `FRONTEND_BASE_PATH`

Default `/front/`. Purely cosmetic (UI only) — change it freely:

```bash
# .env
FRONTEND_BASE_PATH=/inventory/      # any non-root path, slash-wrapped
```
```bash
docker compose up -d frontend            # recreate frontend only — NOT `restart`
```

The UI is then served at `https://<host>/inventory/ocsreports`, assets at
`/inventory/assets/...`, and the runtime config at `/inventory/config/config.json`.

## API base path — `API_BASE_PATH`

Default `/api/`. Single source of truth: it drives the nginx `/api/` location
**and** the backend `FORCE_SCRIPT_NAME`. `BACKEND_API_ROUTE` is re-derived to
match.

```bash
# .env
API_BASE_PATH=/backend/
```
```bash
docker compose up -d frontend backend    # both pick up the shared variable
```

:::warning
The API prefix is an **external contract**: every deployed OCS agent has the URL
configured (`https://<host>/api/asset/legacy/`). Changing it means
**reconfiguring all agents**. Treat it as a deploy-time decision, not a casual
toggle. The UI base path has no such constraint.
:::

## How it works under the hood

The frontend image is built with a distinctive **sentinel** base
(`/__OCS_BASE__/`). At startup the entrypoint substitutes the sentinel with the
requested `FRONTEND_BASE_PATH` across the built assets, writes
`config/config.json` with `BACKEND_API_ROUTE`, and renders the nginx server from
a template. Because everything derives from the same two variables, there is no
way for the assets, the router and the proxy to disagree.

## Constraints

* Both paths must be **non-root** (`/` is reserved for the redirect to the UI)
  and **slash-wrapped** — i.e. they start and end with `/` (e.g. `/x/`).
* `FRONTEND_BASE_PATH` and `API_BASE_PATH` must differ.

## Recreate, don't restart

A new value is read at container start, so use `docker compose up -d <service>`
(recreate). `docker compose restart` reuses the old environment and will not pick
up the change.
