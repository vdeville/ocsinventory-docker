#!/bin/sh
# Runs from the stock nginx image entrypoint (/docker-entrypoint.d/*) before nginx starts, on every container start.
# Makes the SPA deployment base path a runtime setting:
#
#   FRONTEND_BASE_PATH=/front/       (default)  -> UI under /front/
#   FRONTEND_BASE_PATH=/inventory/              -> UI under /inventory/
#
# It materializes the immutable master build under the requested base segment, rebases the build-time sentinel, writes the runtime config.json, and renders the nginx config from the template — all from one variable, so assets and routing stay in sync.
set -eu

MASTER="/opt/ocs-frontend"
DOCROOT="/usr/share/nginx/html"
SENTINEL="/__OCS_BASE__/"
TEMPLATE="/etc/nginx/ocs/default.conf.template"

# Normalize a path to exactly one leading and one trailing slash.
normalize_path() {
    p="$1"
    case "${p}" in /*) ;; *) p="/${p}" ;; esac
    case "${p}" in */) ;; *) p="${p}/" ;; esac
    printf '%s' "${p}"
}

# --- UI base path --------------------------------------------------------
BASE="$(normalize_path "${FRONTEND_BASE_PATH:-/front/}")"
# Directory segment (no leading/trailing slash): "/front/" -> "front".
SEG="$(printf '%s' "${BASE}" | sed 's#^/##; s#/*$##')"
if [ -z "${SEG}" ]; then
    echo "[ocs-frontend] FRONTEND_BASE_PATH cannot be '/' (root). Use e.g. /front/." >&2
    exit 1
fi

# --- API base path (single source, shared with the backend FORCE_SCRIPT_NAME) -
API_BASE="$(normalize_path "${API_BASE_PATH:-/api/}")"
if [ "${API_BASE}" = "${BASE}" ]; then
    echo "[ocs-frontend] API_BASE_PATH and FRONTEND_BASE_PATH must differ." >&2
    exit 1
fi

# --- Backend URL: explicit, else derived from PUBLIC_URL + API base ------
if [ -z "${BACKEND_API_ROUTE:-}" ]; then
    if [ -z "${PUBLIC_URL:-}" ]; then
        echo "[ocs-frontend] set BACKEND_API_ROUTE, or PUBLIC_URL to derive it." >&2
        exit 1
    fi
    BACKEND_API_ROUTE="$(printf '%s' "${PUBLIC_URL}" | sed 's#/*$##')${API_BASE}"
fi

echo "[ocs-frontend] UI base = ${BASE} (segment '${SEG}'), API base = ${API_BASE}, backend = ${BACKEND_API_ROUTE}"

# Materialize the SPA under the requested segment, always from the pristine master, so repeated starts / base changes are idempotent.
rm -rf "${DOCROOT:?}/${SEG}"
mkdir -p "${DOCROOT}/${SEG}"
cp -a "${MASTER}/." "${DOCROOT}/${SEG}/"

# Rebase the baked sentinel to the requested base in all text assets.
find "${DOCROOT}/${SEG}" -type f \( -name '*.html' -o -name '*.js' -o -name '*.css' \) \
    -exec sed -i "s#${SENTINEL}#${BASE}#g" {} +

# Runtime SPA config (backend URL); changeable without rebuild.
mkdir -p "${DOCROOT}/${SEG}/config"
cat > "${DOCROOT}/${SEG}/config/config.json" <<EOF
{
  "BACKEND_API_ROUTE": "${BACKEND_API_ROUTE}"
}
EOF

# Ports nginx listens on (also the public ports).
OCS_HTTP_PORT="${HTTP_PORT:-80}"
OCS_HTTPS_PORT="${HTTPS_PORT:-443}"

# Authority for the HTTP->HTTPS redirect.
# The port is included only when it is non-default, so a non-standard public HTTPS port is preserved.
# The literal "$host" stays an nginx variable (envsubst does not re-scan substituted values).
if [ "${OCS_HTTPS_PORT}" = "443" ]; then
    OCS_HTTPS_AUTHORITY='$host'
else
    OCS_HTTPS_AUTHORITY="$(printf '$host:%s' "${OCS_HTTPS_PORT}")"
fi

# Backend upstream (host:port).
# BACKEND_RESOLVER enables runtime DNS re-resolution; leave it empty to use a static address.
OCS_BACKEND_UPSTREAM="${BACKEND_UPSTREAM:-backend:8000}"
if [ -n "${BACKEND_RESOLVER:-}" ]; then
    OCS_RESOLVER_LINE="resolver ${BACKEND_RESOLVER} valid=10s ipv6=off;"
else
    OCS_RESOLVER_LINE=""
fi

# Render the nginx config from the template (only our vars are substituted).
export OCS_HTTP_PORT OCS_HTTPS_PORT OCS_HTTPS_AUTHORITY
export OCS_BACKEND_UPSTREAM OCS_RESOLVER_LINE
export OCS_BASE="${BASE}" OCS_API_BASE="${API_BASE}"
mkdir -p /etc/nginx/conf.d
envsubst '${OCS_HTTP_PORT} ${OCS_HTTPS_PORT} ${OCS_HTTPS_AUTHORITY} ${OCS_BASE} ${OCS_API_BASE} ${OCS_RESOLVER_LINE} ${OCS_BACKEND_UPSTREAM}' \
    < "${TEMPLATE}" > /etc/nginx/conf.d/default.conf

echo "[ocs-frontend] served from ${DOCROOT}/${SEG}, rendered /etc/nginx/conf.d/default.conf"
