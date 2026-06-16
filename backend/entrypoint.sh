#!/bin/sh
# Role-aware entrypoint for the OCS Inventory backend image.
#
#   OCS_ROLE=init        run migrations once, then exit 0
#   OCS_ROLE=web         wait for DB + migrations, then exec "$@" (gunicorn)
#   OCS_ROLE=automation  wait for DB + migrations, then exec "$@" (scheduler loop)
#
# Migrations ship with the application and are applied idempotently (this entrypoint never runs makemigrations), keeping version upgrades reproducible.

set -eu

OCS_ROLE="${OCS_ROLE:-web}"
cd /app

log() { echo "[entrypoint][$(date -u +%H:%M:%S)][${OCS_ROLE}] $*"; }

wait_for_db() {
    log "Waiting for database to accept connections..."
    timeout="${DB_WAIT_TIMEOUT:-60}"
    elapsed=0
    until python -c "import django; django.setup(); from django.db import connections; connections['default'].ensure_connection()" 2>/dev/null; do
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${timeout}" ]; then
            log "Database not reachable after ${timeout}s. Exiting."
            exit 1
        fi
        sleep 2
    done
    log "Database is up."
}

wait_for_migrations() {
    log "Waiting for migrations to be applied (by the init service)..."
    timeout="${MIGRATE_WAIT_TIMEOUT:-300}"
    elapsed=0
    until python manage.py migrate --check >/dev/null 2>&1; do
        elapsed=$((elapsed + 3))
        if [ "${elapsed}" -ge "${timeout}" ]; then
            log "Migrations still pending after ${timeout}s. Exiting."
            exit 1
        fi
        sleep 3
    done
    log "Migrations are applied."
}

bootstrap_admin_password() {
    # Bootstrap only: applies OCS_ADMIN_PASSWORD to the 'admin' superuser ONLY while it still has the insecure default password ('admin', from user/migrations/0001).
    # Once changed — by this step or later via the UI — it is never touched again, so password changes are preserved across restarts/upgrades.
    # Rotate afterwards via the UI or `manage.py changepassword`.
    [ -n "${OCS_ADMIN_PASSWORD:-}" ] || return 0
    log "Bootstrapping the 'admin' password (only if still the default)..."
    OCS_ADMIN_PASSWORD="${OCS_ADMIN_PASSWORD}" python manage.py shell <<'PY'
import os
from django.contrib.auth import get_user_model

User = get_user_model()
pwd = os.environ["OCS_ADMIN_PASSWORD"]
try:
    user = User.objects.get(username="admin")
except User.DoesNotExist:
    print("admin user not found (skipping)")
else:
    if user.check_password("admin"):
        user.set_password(pwd)
        user.is_active = True
        user.save(update_fields=["password", "is_active"])
        print("admin password initialized from OCS_ADMIN_PASSWORD")
    else:
        print("admin password already set — left untouched")
PY
}

case "${OCS_ROLE}" in
    init)
        # Static files are baked into the image at build time (WhiteNoise), so init only handles the database + first admin.
        wait_for_db
        log "Applying migrations (includes group/permission setup)..."
        python manage.py migrate --noinput
        bootstrap_admin_password
        log "Initialization complete."
        exit 0
        ;;
    web|automation)
        wait_for_db
        wait_for_migrations
        log "Starting: $*"
        exec "$@"
        ;;
    *)
        log "Unknown OCS_ROLE='${OCS_ROLE}'. Expected init|web|automation."
        exit 1
        ;;
esac
