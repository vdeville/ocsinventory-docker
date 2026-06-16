"""
Production settings overlay for the Dockerized OCS Inventory backend.

This module is shipped *alongside* the upstream `settings.py` (it is copied into the image, the upstream source is never modified).
It imports everything from the upstream settings and only overrides what is needed for a clean, secure, reverse-proxied container deployment driven by environment variables.

Activated via `DJANGO_SETTINGS_MODULE=ocsinventory_backend.settings_docker`.
"""

import os

from .settings import *  # noqa: F401,F403  (inherit all upstream settings)


def _bool(name, default=False):
    """Parse a boolean from an environment variable (accepts 1/true/yes/on)."""
    return str(os.getenv(name, default)).strip().lower() in ("1", "true", "yes", "on")


def _csv(name, default=""):
    return [item.strip() for item in os.getenv(name, default).split(",") if item.strip()]


# --- Core security -----------------------------------------------------------
DEBUG = _bool("DEBUG", False)

# SECRET_KEY is already read from the environment by the upstream settings.
# It MUST be provided (stable) so sessions/tokens survive restarts and upgrades.
if not DEBUG and not SECRET_KEY:  # noqa: F405
    raise RuntimeError(
        "SECRET_KEY environment variable is required when DEBUG is disabled."
    )

ALLOWED_HOSTS = _csv("ALLOWED_HOSTS", "*") or ["*"]
CSRF_TRUSTED_ORIGINS = _csv("CSRF_TRUSTED_ORIGINS")


# --- Database ----------------------------------------------------------------
# Only PostgreSQL is supported (psycopg2 is installed in the image); the engine is pinned here and DB_ENGINE is not exposed as an environment variable.
DATABASES["default"]["ENGINE"] = "django.db.backends.postgresql"  # noqa: F405


# --- Frontend redirect (SSO callbacks) ---------------------------------------
# After a CAS/OIDC login the backend redirects the browser to the SPA with the auth token in the URL fragment (#token_authentication=...).
# Derived from PUBLIC_URL + FRONTEND_BASE_PATH (+ the SPA's /ocsreports route) so it tracks the UI base path automatically.
# Set FRONTEND_REDIRECT explicitly to override (e.g. split-origin); empty when PUBLIC_URL is unset (the SSO redirect is then simply disabled).
# Not used for local username/password login.
def _derive_frontend_redirect():
    explicit = os.getenv("FRONTEND_REDIRECT")
    if explicit:
        return explicit
    public = os.getenv("PUBLIC_URL", "").rstrip("/")
    if not public:
        return ""
    base = os.getenv("FRONTEND_BASE_PATH", "/front/").strip("/")
    base = f"/{base}/" if base else "/"
    return f"{public}{base}ocsreports"


FRONTEND_REDIRECT = _derive_frontend_redirect()

# --- Reverse proxy / sub-path mounting --------------------------------------
# The app is served under API_BASE_PATH (default /api/) by the edge nginx, which strips that prefix before proxying.
# FORCE_SCRIPT_NAME makes Django regenerate absolute URLs (static, redirects, DRF) with the prefix.
# Single source of truth: API_BASE_PATH (shared with nginx); FORCE_SCRIPT_NAME kept for back-compat.
FORCE_SCRIPT_NAME = (
    os.getenv("API_BASE_PATH") or os.getenv("FORCE_SCRIPT_NAME") or "/api"
).rstrip("/") or "/api"
USE_X_FORWARDED_HOST = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

_prefix = FORCE_SCRIPT_NAME.rstrip("/")
STATIC_URL = f"{_prefix}/static/"
MEDIA_URL = f"{_prefix}/media/"

# TLS is terminated by the edge nginx; do not force-redirect inside Django.
SECURE_SSL_REDIRECT = _bool("SECURE_SSL_REDIRECT", False)

# --- CORS --------------------------------------------------------------------
# Front and API share the same origin behind the single hostname, so CORS is not required by default.
# Kept configurable for split-origin deployments.
CORS_ALLOW_ALL_ORIGINS = _bool("CORS_ALLOW_ALL_ORIGINS", False)
CORS_ALLOWED_ORIGINS = _csv("CORS_ALLOWED_ORIGINS")

# --- Static files via WhiteNoise --------------------------------------------
# Avoids sharing a static volume with nginx.
# WhiteNoise serves /static/ straight from the WSGI app (Django admin + DRF browsable API assets).
if "whitenoise.middleware.WhiteNoiseMiddleware" not in MIDDLEWARE:  # noqa: F405
    MIDDLEWARE = (  # noqa: F405
        MIDDLEWARE[:1]  # noqa: F405  (keep SecurityMiddleware first)
        + ["whitenoise.middleware.WhiteNoiseMiddleware"]
        + MIDDLEWARE[1:]  # noqa: F405
    )

STORAGES = {
    **globals().get("STORAGES", {}),
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
    },
}

# nginx strips the /api prefix before proxying, so the app receives /static/... while STATIC_URL (used for URL generation) keeps the /api prefix.
# Tell WhiteNoise to match the stripped prefix it actually receives.
WHITENOISE_STATIC_PREFIX = "/static/"

# --- Logging -> stdout -------------------------------------------------------
# Replace the upstream file-based handlers so logs are captured by `docker logs`.
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "[{levelname}][{asctime}][{name}]: {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": os.getenv("LOG_LEVEL", "INFO"),
    },
}
