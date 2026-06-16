---
description: "Manage the OCS Inventory admin account, authentication (local and CAS/OIDC/LDAP SSO), and the agent inventory endpoints."
---

# Admin, auth & agents

## The bootstrap admin account

Migrations create an `admin` superuser with the insecure default password
`admin`. The `ocs-init` step replaces it with `OCS_ADMIN_PASSWORD` — but **only
while the password is still the default**. Once it has been changed (by this
bootstrap, or later in the UI), it is never touched again, so your password
changes survive restarts and upgrades.

| State at init | Result |
|---------------|--------|
| Fresh DB, `OCS_ADMIN_PASSWORD` set | password set from the env var |
| Password already changed | left untouched |
| `OCS_ADMIN_PASSWORD` empty on a fresh DB | stays `admin/admin` (set it later — it applies while still default) |

Rotate the password afterwards via the UI or:

```bash
docker compose exec backend python manage.py changepassword admin
```

:::warning
Always set `OCS_ADMIN_PASSWORD` before the first start, or change `admin/admin`
immediately after.
:::

## Authentication methods

* **Local** (username/password): the SPA calls `<api>/api-auth/token` and stores
  the returned token — `FRONTEND_REDIRECT` is not involved.
* **SSO / directory** (CAS, OIDC, LDAP): see the next section.

## Single Sign-On (CAS / OIDC / LDAP)

The auth backends are already bundled in the image (`django-cas-ng`,
`mozilla-django-oidc`, `django-auth-ldap`). The **provider configuration lives in
OCS itself**, not in this stack's `.env` — there is no image rebuild and no
stack-specific env var for the provider credentials.

**1. Configure the provider in OCS.** In the UI go to **Configurations →
Authentication** (`https://<host>/front/ocsreports/configurations/authentication`).
Add and enable a CAS / OIDC / LDAP method and fill in its settings — OIDC issuer,
client id & secret, scopes; CAS server URL; LDAP host / bind DN / base. These are
stored in the database. Refer to the
[official OCS documentation](https://documentation.ocsinventory-ng.org/) for the
exact fields.

**2. Register the callback at your provider.** For OIDC/CAS, the redirect /
callback URL to declare is:

```
https://<host>/api/callback/
```

The backend also exposes `/api/login/` and `/api/logout/`. (These follow
`API_BASE_PATH`, so adjust the prefix if you changed it.)

**3. Check the stack-side settings.**

* `CSRF_TRUSTED_ORIGINS` must include your public origin.
* `FRONTEND_REDIRECT` is where the backend sends the browser after a successful
  login, with the auth token in the URL fragment. Leave it empty to derive it
  from `PUBLIC_URL` + `FRONTEND_BASE_PATH` + `ocsreports`.

Both are plain env vars — see
[Environment variables](../configuration/environment-variables.md).

## Pointing OCS agents at the server

Agents talk to the **API** base path:

* Legacy/v2 agents (XML + zlib): `https://<host>/api/asset/legacy/`
* Collection endpoint: `https://<host>/api/asset/collection/`

The edge accepts large bodies (`client_max_body_size 200m`) for full
inventories.

:::warning
The API base path is part of the agent configuration. If you change
`API_BASE_PATH`, you must reconfigure every deployed agent. See
[Base paths](../configuration/base-paths.md).
:::
