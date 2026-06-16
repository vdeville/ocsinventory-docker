---
description: "GitHub Actions workflows for the OCS Inventory Docker project: validation, tag-triggered GHCR publishing, and docs deployment."
---

# GitHub Actions & images

Two workflows live in `.github/workflows/`.

## `ci.yml` — validation (pull requests & pushes)

* **Lint** — hadolint on both Dockerfiles, ShellCheck on the entrypoints (error
  severity), `docker compose config` on the base and the dev-merged files.
* **Build** — builds both images (no push) via the dev override, to catch
  breakage early.

Hadolint noise is tuned in `.hadolint.yaml` (ignores apt/pip version-pin rules
and the intentional word-splitting in the `EXTRA_*` args / patch loop).

## `build-and-push.yml` — publish to GHCR

Triggers: **pushing a git tag** matching `[0-9]*` (i.e. the version string, e.g.
`3.0.0-rc1`), or a manual `workflow_dispatch` with that version as input. It
builds **only the tagged version** — not the whole manifest.

1. **prepare** — takes the version from the tag name (`github.ref_name`, optional
   leading `v` stripped) or the dispatch input, looks up its entry in
   `versions.json` with `jq`, and emits a **single-entry** build matrix (refs +
   the optional `EXTRA_*`). A tag with no matching entry in `versions.json` fails
   the job immediately.
2. **build** — for that version, on `linux/amd64` + `linux/arm64`:
   * logs in to GHCR with the automatic `GITHUB_TOKEN` (no secrets to configure);
   * uses `docker/metadata-action` to compute tags and labels;
   * builds and pushes `backend` and `frontend` with `docker/build-push-action`,
     using the GitHub Actions layer cache (`type=gha`).

Tags published: `:<version>` only (no moving `:latest`).

The `arm64` image is built under QEMU emulation — slower than `amd64` (the
`python-ldap` C extension compiles), but it succeeds. If a release needs an extra
build library, add it via `backend_extra_build_apt` (see
[Publishing a version](releasing.md)).

## Image names

```
ghcr.io/<owner>/ocsinventory-backend
ghcr.io/<owner>/ocsinventory-frontend
```

`<owner>` is the repository owner (`github.repository_owner`), so a fork
publishes under its own namespace automatically.

## Labels (OCI)

Static identity is baked into the Dockerfiles (`title`, `description`, `vendor`,
`authors`, `licenses=GPL-3.0-only`, `version`). The dynamic labels (`created`,
`revision`, `source`, `url`) are added by `docker/metadata-action` at push time —
which overrides same-key labels via `--label`. That's why the Dockerfiles only
hardcode the stable identity.

## Build cache note

The `type=gha` cache stores whole **layers**, so an unchanged-dependency build is
skipped entirely. BuildKit `RUN --mount=type=cache` mounts (for pip/npm download
caches) are not persisted across CI runs by that backend; they would mainly speed
up local rebuilds. They are not enabled by default.
