---
description: "Repository layout and build arguments for the OCS Inventory Docker images, and how to build them from source."
---

# Project layout

```
compose.yaml          production stack (prebuilt GHCR images)
compose.dev.yaml      dev override: build images from source
.env.example          configuration template
versions.json         build manifest (OCS versions)
.hadolint.yaml        Dockerfile lint config

backend/   Dockerfile · entrypoint.sh · gunicorn.conf.py · overlay/settings_docker.py
frontend/       Dockerfile · default.conf.template · entrypoint.sh · patches/<ref>/
certs/     mount fullchain.pem / privkey.pem here (gitignored)
examples/  standalone compose.yaml + .env.example (the Getting started bundle)

.github/workflows/
  ci.yml                lint + build on PRs/pushes
  build-and-push.yml    matrix build + push images to GHCR
  docs.yml              build + deploy this site to GitHub Pages

docs/      this documentation (Markdown)
website/   Docusaurus site that renders docs/ (deployed to GitHub Pages)
```

## The single backend image, three roles

`backend`, `ocs-init` and `automation` all run
`ghcr.io/<owner>/ocsinventory-backend`, differentiated by `OCS_ROLE`
(`web` / `init` / `automation`).

## Build & run from source

`compose.yaml` pulls prebuilt images. To build them locally, add the dev
override `compose.dev.yaml` (only `backend` and `frontend` carry a build section;
`ocs-init`/`automation` reuse the backend image, so it is built once):

```bash
docker compose -f compose.yaml -f compose.dev.yaml build
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

Set `COMPOSE_FILE=compose.yaml:compose.dev.yaml` in your shell or `.env` to drop
the `-f` flags on every command.

Version-specific build inputs (refs, extra packages, source patches) come from
`versions.json` and `frontend/patches/<ref>/` — see [Publishing a version](releasing.md).

## Build arguments

Passed at build time only — set in `.env` (interpolated into the build) or via
`--build-arg`. Most builds need only the version refs.

| Argument | Default | Description |
|----------|---------|-------------|
| `OCS_BACKEND_REF` | `3.0.0-rc1` | Backend git tag/branch to build (also the image tag). |
| `OCS_FRONTEND_REF` | `3.0.0-rc1` | Frontend git tag/branch to build (also the image tag). |
| `EXTRA_BUILD_APT` | _(empty)_ | Extra apt packages in the backend **builder** stage. |
| `EXTRA_RUNTIME_APT` | _(empty)_ | Extra apt packages in the backend **runtime** stage. |
| `EXTRA_PIP` | _(empty)_ | Extra pip packages installed in the backend venv. |
| `GUNICORN_VERSION` | `23.0.0` | Pinned gunicorn version. |
| `WHITENOISE_VERSION` | `6.7.0` | Pinned WhiteNoise version. |
| `OCS_BACKEND_REPO` / `OCS_FRONTEND_REPO` | upstream GitHub URLs | Source repositories to clone. |
| `VITE_BASE_PATH` | `/__OCS_BASE__/` (sentinel) | Frontend build base — **do not** set to a real path; the base is chosen at runtime. |

`OCS_*_REF` is also a runtime setting — it selects which published image to pull,
so it is documented in [Environment variables](../configuration/environment-variables.md)
too. See [Publishing a version](releasing.md) and [Source patches](patches.md).

### Using a custom Dockerfile

In the rare case where a version ships its own Dockerfile (see
[Publishing a version](releasing.md)):

* **Published images (CI)** — set `backend_dockerfile` (or `frontend_dockerfile`) on
  the version entry in `versions.json`; the workflow builds with it as `file:`.
* **Local build** — just point the service's `build.dockerfile` at it in
  `compose.dev.yaml`:

  ```yaml
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.3.1.0
  ```

## Editing this documentation

The docs are Markdown in `docs/`; `website/` is the Docusaurus site that renders
them. To preview locally:

```bash
cd website
npm install
npm run start      # live-reload dev server
```

A push to `main` that touches `docs/` or `website/` triggers
`.github/workflows/docs.yml`, which builds and deploys to GitHub Pages.
