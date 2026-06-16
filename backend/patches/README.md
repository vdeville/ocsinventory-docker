# Backend source patches

Place patches that must be applied to the upstream backend source here, one
directory per OCS version:

```
backend/patches/<backend_ref>/000-something.patch
backend/patches/<backend_ref>/010-another.patch
```

The Dockerfile applies every `*.patch` in `patches/<OCS_BACKEND_REF>/` in
filename order (prefix `000-`, `010-`, … to sequence them). A version with no
directory here builds unmodified. Drop a patch once it ships upstream.
