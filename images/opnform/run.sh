#!/bin/sh
# Runs after the upstream entrypoint's API setup. Creates the first user from env (once, before anything listens
# publicly), then supervises php-fpm, the queue worker, the scheduler and nginx: if any of them exits, the container
# exits and Railway restarts it.
set -eu
cd /usr/share/nginx/html

log() { printf 'opnform-railway: %s\n' "$*"; }

# 1. First user. Nothing listens on $PORT yet, so nobody can race the setup-mode registration.
if [ -n "${ADMIN_EMAIL:-}" ]; then
  php /etc/opnform-railway/bootstrap-admin.php || { log "first-user bootstrap failed"; exit 1; }
else
  log "ADMIN_EMAIL is not set; skipping the first-user bootstrap"
fi

# 2. nginx config.
ns=$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf)
[ -n "$ns" ] || ns=127.0.0.11
case "$ns" in *:*) ns="[$ns]" ;; esac
sed -e "s|@PORT@|${PORT:-8080}|g" \
    -e "s|@RESOLVER@|$ns|g" \
    -e "s|@CLIENT_UPSTREAM@|${CLIENT_UPSTREAM}|g" \
    -e "s|@MAX_BODY@|${NGINX_MAX_BODY_SIZE:-64m}|g" \
    /etc/opnform-railway/nginx.conf.template >/etc/nginx/nginx.conf
nginx -t -q

# 3. Processes.
php ./artisan app:scheduler-status --mode=record >/dev/null 2>&1 || true

pids=""
start() { "$@" & pids="$pids $!"; }
stop_all() { for p in $pids; do kill "$p" 2>/dev/null || true; done; }
trap 'stop_all; exit 0' TERM INT

start php-fpm
start php ./artisan queue:work --sleep=3 --tries=3
start php ./artisan schedule:work
start nginx -g 'daemon off;'
log "listening on port ${PORT:-8080} (client upstream ${CLIENT_UPSTREAM})"

# Exit as soon as any child exits.
while :; do
  for p in $pids; do
    if ! kill -0 "$p" 2>/dev/null; then
      log "process $p exited; stopping the container"
      stop_all
      exit 1
    fi
  done
  sleep 5
done
