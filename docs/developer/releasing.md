---
description: "Publish a new OCS Inventory version with the versions.json manifest and the git-tag-triggered multi-arch image build."
---

# Releasing a version

Image builds are driven by a single manifest (`versions.json`) over **generic,
parameterized Dockerfiles** — with per-version escape hatches (extra packages,
patch control, or a custom Dockerfile) when a release needs more.

## `versions.json`

```json
{
  "versions": [
    { "version": "3.0.0-rc1", "backend_ref": "3.0.0-rc1", "frontend_ref": "3.0.0-rc1" }
  ]
}
```

* `version` — the image tag to publish (`:<version>`).
* `backend_ref` / `frontend_ref` — the upstream git tags to build from.

## Adding a new OCS release

**1. Append an entry:**

```json
{
  "versions": [
    { "version": "3.0.0-rc1", "backend_ref": "3.0.0-rc1", "frontend_ref": "3.0.0-rc1" },
    { "version": "3.0.0-rc2", "backend_ref": "3.0.0-rc2", "frontend_ref": "3.0.0-rc2" }
  ]
}
```

**2. Commit, then tag the repo with that version** to trigger the build:

```bash
git commit -am "Add OCS 3.0.0-rc2"
git push
git tag 3.0.0-rc2        # the tag MUST equal the `version` field
git push origin 3.0.0-rc2
```

The push of the tag triggers `build-and-push.yml`, which builds **only that
version** and pushes `:3.0.0-rc2`. Editing `versions.json` alone does **not**
build anything — the git tag is the trigger. You can also run the workflow manually (`workflow_dispatch`) with the
version as input. See [Workflows](workflows.md).

## Version-specific needs

Most version bumps need nothing but the refs. Optional per-version fields in
`versions.json` cover the rest, all without forking the generic Dockerfile:

| Need | Field |
|------|-------|
| Extra build library (builder stage) | `backend_extra_build_apt` |
| Extra runtime library | `backend_extra_runtime_apt` |
| Extra Python package | `backend_extra_pip` |
| Use a custom Dockerfile (last resort) | `backend_dockerfile` / `frontend_dockerfile` |

Source patches need **no** manifest config — see below.

Example:

```json
{
  "version": "3.1.0",
  "backend_ref": "3.1.0",
  "frontend_ref": "3.1.0",
  "backend_extra_pip": "some-new-dependency==1.2.3",
  "backend_extra_runtime_apt": "libfoo1"
}
```

## Source patches

For changes not yet in an upstream release, drop git patches in a folder named
after the ref — `backend/patches/<backend_ref>/` or `frontend/patches/<frontend_ref>/`
— and they're applied in filename order at build time. No manifest config.

See [Source patches](patches.md) for the full guide.

## Custom Dockerfile for one version (last resort)

If a version needs a structurally different build (different base image or
steps), add a dedicated Dockerfile **next to the generic one** — so the build
context and `overlay/`, `entrypoint.sh`, etc. stay available — and point the
version at it:

1. Add `backend/Dockerfile.3.1.0` (filename relative to the `backend/` context).
2. Reference it in `versions.json`:
   ```json
   {
     "version": "3.1.0",
     "backend_ref": "3.1.0",
     "frontend_ref": "3.1.0",
     "backend_dockerfile": "Dockerfile.3.1.0"
   }
   ```
   `frontend_dockerfile` works the same for the frontend image.

Every other version keeps using the default `Dockerfile`. To build it locally,
point `build.dockerfile` at it in `compose.dev.yaml`:

```yaml
backend:
  build:
    context: ./backend
    dockerfile: Dockerfile.3.1.0
```
