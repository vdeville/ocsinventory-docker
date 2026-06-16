---
description: "Configuration model of the OCS Inventory Docker stack: environment variables, runtime base paths, TLS, and the Django settings overlay."
---

# Configuration model

All configuration is driven by a single **`.env`** file (copied from
`.env.example`). Compose reads it for variable interpolation and passes the
values to the containers.

## Three kinds of settings

| Kind | When it applies | Examples |
|------|-----------------|----------|
| **Runtime** | read at container start; change with `docker compose up -d <service>` (no rebuild) | base paths, ports, secrets, DB connection, admin password |
| **Build** | baked into the image at build time (build args) | OCS version refs, extra packages |
| **Derived** | computed from other variables when left empty | `BACKEND_API_ROUTE`, `FRONTEND_REDIRECT`, `FORCE_SCRIPT_NAME` |

## Derivation (leave it empty, it computes)

To avoid drift between related values, some variables are derived from
`PUBLIC_URL` and the base paths when you leave them blank:

* `BACKEND_API_ROUTE` → `PUBLIC_URL` + `API_BASE_PATH` (the URL the browser calls).
* `FRONTEND_REDIRECT` → `PUBLIC_URL` + `FRONTEND_BASE_PATH` + `ocsreports` (SSO).
* `FORCE_SCRIPT_NAME` → `API_BASE_PATH` (so Django and nginx share one prefix).

Set them explicitly only for non-standard topologies (e.g. split-origin).

## Applying a change

* A change picked up at container start needs a **recreate**, not a restart:

  ```bash
  docker compose up -d <service>     # recreates with the new env
  ```

  `docker compose restart` reuses the existing environment and will **not** pick
  up new values.

* A build-time change (version ref, extra package) needs a rebuild or a new
  image pull.

## Reference

* [Environment variables](environment-variables.md) — the complete list.
* [Base paths](base-paths.md), [TLS & networking](tls-and-networking.md),
  [Django settings overlay](django-overlay.md) — the topics in depth.
