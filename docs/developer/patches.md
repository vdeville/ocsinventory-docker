---
description: "Apply per-version source patches to the OCS Inventory backend and frontend at build time, with no manifest configuration."
---

# Source patches

Sometimes a fix or feature isn't in an upstream OCS release yet but you need it
in the image (the configurable base path is the current example). The stack
applies such changes as **git patches** at build time, with one rule:

> **One version = one folder. Every `*.patch` in it is applied, in filename
> order. No manifest entry, no flags.**

The backend and the frontend image work exactly the same way.

## Where patches live

```
backend/patches/<backend_ref>/000-something.patch
backend/patches/<backend_ref>/010-another.patch

frontend/patches/<frontend_ref>/000-frontend-base-path-aware.patch
```

`<backend_ref>` / `<frontend_ref>` are the git tags the image builds from
(`OCS_BACKEND_REF` / `OCS_FRONTEND_REF`, i.e. the values from `versions.json`).

## How they're applied

Each Dockerfile, right after cloning the upstream source at its ref:

1. looks for the directory `patches/<ref>/`;
2. if it exists, runs `git apply` on every `*.patch` inside, in **filename
   order** (the shell sorts the glob);
3. if it doesn't exist, the source builds unmodified.

A failing `git apply` **stops the build**, so a stale or conflicting patch
surfaces immediately instead of producing a broken image.

Because the folder is named after the ref, two OCS versions can carry different
patches with zero coordination.

## Sequencing

Patches in a folder apply alphabetically — prefix them with a number to control
order:

```
frontend/patches/3.0.0-rc1/000-base-path.patch
frontend/patches/3.0.0-rc1/010-some-follow-up.patch
```

## Adding a patch

Produce a patch from a clone of the upstream repo at the target ref:

```bash
# Example: a frontend change for 3.0.0-rc2
git clone --branch 3.0.0-rc2 \
  https://github.com/OCSInventory-NG/OCSInventory-Server-Frontend-Rework.git /tmp/ocs-front
cd /tmp/ocs-front
# … edit files …
mkdir -p <repo>/frontend/patches/3.0.0-rc2
git diff > <repo>/frontend/patches/3.0.0-rc2/010-my-change.patch
```

The same applies to the backend with the backend repo and
`backend/patches/<backend_ref>/`. `git diff` output (with `a/` … `b/` paths) is
exactly what `git apply` consumes in the build.

## Removing or skipping a patch

* Delete the `*.patch` file to stop applying just that change.
* Delete the whole `patches/<ref>/` directory to build that version unmodified.

When a patch is merged into a tagged upstream release, bump that version's
`*_ref` to the new tag and delete its patch directory — nothing else to change.

## Test it locally

Build from source with the dev override and watch the log for `Applying patch:`:

```bash
docker compose -f compose.yaml -f compose.dev.yaml build frontend      # or backend
```
