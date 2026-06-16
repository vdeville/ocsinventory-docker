# Frontend source patches

Place patches that must be applied to the upstream frontend source here, one
directory per OCS version:

```
frontend/patches/<frontend_ref>/000-something.patch
frontend/patches/<frontend_ref>/010-another.patch
```

The Dockerfile applies every `*.patch` in `patches/<OCS_FRONTEND_REF>/` in
filename order (prefix `000-`, `010-`, … to sequence them). A version with no
directory here builds unmodified. Drop a patch once it ships upstream.
