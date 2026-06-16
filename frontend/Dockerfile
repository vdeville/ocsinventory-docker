# syntax=docker/dockerfile:1

############################
# Stage 1 — frontend build
############################
FROM node:22-alpine AS builder

ARG OCS_FRONTEND_REPO="https://github.com/OCSInventory-NG/OCSInventory-Server-Frontend-Rework.git"
ARG OCS_FRONTEND_REF="3.0.0-rc1"
# Build with a distinctive sentinel base so the deployment base path can be chosen at container start (substituted by the entrypoint).
# Do NOT set this to a real path — it is replaced at runtime by $FRONTEND_BASE_PATH.
ARG VITE_BASE_PATH="/__OCS_BASE__/"
RUN apk add --no-cache git

WORKDIR /src

# Pinned source checkout — upgrade = bump OCS_FRONTEND_REF.
RUN git clone --depth 1 --branch "${OCS_FRONTEND_REF}" "${OCS_FRONTEND_REPO}" .

# Apply this version's source patches, if any: patches/<ref>/*.patch, in filename order (prefix files 000-, 010-, … to sequence them).
# A version with no such directory builds unmodified.
COPY patches/ /tmp/patches/
RUN set -eu; \
    dir="/tmp/patches/${OCS_FRONTEND_REF}"; \
    if [ -d "${dir}" ]; then \
        for p in "${dir}"/*.patch; do \
            [ -e "${p}" ] || continue; \
            echo "Applying patch: ${p}"; \
            git apply "${p}"; \
        done; \
    fi

RUN npm ci; \
    VITE_BASE_PATH="${VITE_BASE_PATH}" npm run build

############################
# Stage 2 — nginx edge
############################
FROM nginx:1.27-alpine AS runtime

# Static image identity.
# Dynamic labels (created, revision, source, url) are added by CI (docker/metadata-action) at build/push time.
ARG OCS_FRONTEND_REF="3.0.0-rc1"
LABEL org.opencontainers.image.title="OCS Inventory Frontend" \
      org.opencontainers.image.description="OCS Inventory frontend (Vue SPA) and nginx edge proxy." \
      org.opencontainers.image.vendor="OCS Inventory" \
      org.opencontainers.image.authors="Valentin Deville <contact@valentin-deville.fr>" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.version="${OCS_FRONTEND_REF}"

# Immutable "master" build (contains the sentinel base).
# At each container start the entrypoint materializes it under the requested base segment, rebases the sentinel and renders the nginx config — so the base path is a runtime knob.
COPY --from=builder /src/dist /opt/ocs-frontend
COPY default.conf.template /etc/nginx/ocs/default.conf.template
COPY entrypoint.sh /docker-entrypoint.d/40-ocs-frontend.sh

RUN chmod +x /docker-entrypoint.d/40-ocs-frontend.sh \
    && rm -f /etc/nginx/conf.d/default.conf

EXPOSE 80 443

# The stock nginx image entrypoint runs /docker-entrypoint.d/* (incl. ours, which generates /etc/nginx/conf.d/default.conf) then launches nginx.
