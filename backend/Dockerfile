# syntax=docker/dockerfile:1

############################
# Stage 1 — builder
############################
# Django 6 requires Python >= 3.12.
# Pin to Debian bookworm for stable package names (libldap-2.5-0); slim (Trixie) renames the runtime lib.
FROM python:3.12-slim-bookworm AS builder

ARG OCS_BACKEND_REPO="https://github.com/OCSInventory-NG/OCSInventory-Server-Backend-Rework.git"
ARG OCS_BACKEND_REF="3.0.0-rc1"
ARG GUNICORN_VERSION="23.0.0"
ARG WHITENOISE_VERSION="6.7.0"
# Optional per-version extras (empty by default; set from the build manifest so a release can add a build lib / pip package without forking the Dockerfile).
ARG EXTRA_BUILD_APT=""
ARG EXTRA_PIP=""

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Build deps: python-ldap (libldap/libsasl), git for the pinned checkout.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        python3-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        pkg-config \
        ${EXTRA_BUILD_APT} \
    && rm -rf /var/lib/apt/lists/*

# Pinned source checkout — upgrade = bump OCS_BACKEND_REF.
RUN git clone --depth 1 --branch "${OCS_BACKEND_REF}" "${OCS_BACKEND_REPO}" /app

WORKDIR /app

# Apply this version's source patches, if any: patches/<ref>/*.patch, in filename order (prefix files 000-, 010-, … to sequence them).
# A version with no such directory builds unmodified.
COPY patches/ /tmp/patches/
RUN set -eu; \
    dir="/tmp/patches/${OCS_BACKEND_REF}"; \
    if [ -d "${dir}" ]; then \
        for p in "${dir}"/*.patch; do \
            [ -e "${p}" ] || continue; \
            echo "Applying patch: ${p}"; \
            git apply "${p}"; \
        done; \
    fi

# Isolated venv (copied as-is into the runtime stage).
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

RUN pip install --upgrade pip \
    && pip install -r requirements.txt \
    && pip install -r requirements_psql.txt \
    && pip install "gunicorn==${GUNICORN_VERSION}" "whitenoise==${WHITENOISE_VERSION}" \
    && if [ -n "${EXTRA_PIP}" ]; then pip install ${EXTRA_PIP}; fi

############################
# Stage 2 — runtime
############################
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:${PATH}" \
    DJANGO_SETTINGS_MODULE=ocsinventory_backend.settings_docker

# Static image identity.
# Dynamic labels (created, revision, source, url) are added by CI (docker/metadata-action) at build/push time.
ARG OCS_BACKEND_REF="3.0.0-rc1"
LABEL org.opencontainers.image.title="OCS Inventory Backend" \
      org.opencontainers.image.description="OCS Inventory backend (Django REST API) served by gunicorn." \
      org.opencontainers.image.vendor="OCS Inventory" \
      org.opencontainers.image.authors="Valentin Deville <contact@valentin-deville.fr>" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.version="${OCS_BACKEND_REF}"

# Runtime libs only: python-ldap shared libs + curl for the healthcheck.
# EXTRA_RUNTIME_APT lets a release add a runtime shared lib without forking.
ARG EXTRA_RUNTIME_APT=""
RUN apt-get update && apt-get install -y --no-install-recommends \
        libldap-2.5-0 \
        libsasl2-2 \
        curl \
        ${EXTRA_RUNTIME_APT} \
    && rm -rf /var/lib/apt/lists/*

# Non-root user (fixed UID/GID so volume ownership is predictable).
RUN groupadd --gid 1001 ocs \
    && useradd --uid 1001 --gid 1001 --home-dir /app --shell /usr/sbin/nologin ocs

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app

# Production settings overlay (does not touch the upstream settings.py).
COPY overlay/ocsinventory_backend/settings_docker.py /app/ocsinventory_backend/settings_docker.py
COPY entrypoint.sh /entrypoint.sh
COPY gunicorn.conf.py /app/gunicorn.conf.py

WORKDIR /app

# Bake static files into the image (immutable, served by WhiteNoise in every container).
# collectstatic does not touch the database; SECRET_KEY is only set to satisfy the settings check at build time.
RUN chmod +x /entrypoint.sh \
    && mkdir -p /app/static /app/media \
    && SECRET_KEY=build-only python manage.py collectstatic --noinput \
    && chown -R ocs:ocs /app

USER ocs

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5 \
    CMD curl --fail http://localhost:8000/api-check/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "-c", "/app/gunicorn.conf.py", "ocsinventory_backend.wsgi:application"]
