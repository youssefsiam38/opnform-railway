#!/bin/sh
# Pre-flight for the OpnForm Railway wrapper, then the stock upstream entrypoint (unmodified): it waits for the
# database, runs migrations, creates the Passport keys in the storage volume and warms the caches, then execs
# opnform-railway-run, which starts php-fpm, the queue worker, the scheduler and nginx.
set -eu

log() { printf 'opnform-railway: %s\n' "$*"; }
need() {
  eval "v=\${$1:-}"
  # shellcheck disable=SC2154
  [ -n "$v" ] || { log "missing required variable $1"; exit 1; }
}

for k in APP_KEY JWT_SECRET FRONT_API_SECRET APP_URL FRONT_URL DB_HOST DB_DATABASE DB_USERNAME DB_PASSWORD REDIS_HOST; do
  need "$k"
done

case "${APP_KEY}" in
  base64:*) ;;
  *) [ "${#APP_KEY}" -eq 32 ] || { log "APP_KEY must be 32 characters (or base64:<32 bytes>)"; exit 1; } ;;
esac

# tymon/jwt-auth (HS256) refuses keys shorter than 256 bits.
[ "${#JWT_SECRET}" -ge 32 ] || { log "JWT_SECRET must be at least 32 characters"; exit 1; }

if [ -n "${ADMIN_EMAIL:-}" ] && [ -z "${ADMIN_PASSWORD:-}" ]; then
  log "ADMIN_EMAIL is set but ADMIN_PASSWORD is empty"; exit 1
fi

# The upstream entrypoint picks its "api" role (migrations etc.) for any command other than queue:work/schedule:work.
exec /usr/local/bin/opnform-entrypoint /usr/local/bin/opnform-railway-run
