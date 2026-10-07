#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Static validation: syntax, shellcheck, compose shape, image pins and security defaults. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "syntax"
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done
for f in images/opnform/entrypoint.sh images/opnform/run.sh; do
  if sh -n "$f"; then pass "parses: $f (POSIX sh)"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck bash"; else fail "shellcheck bash"; fi
  if shellcheck -s sh images/opnform/entrypoint.sh images/opnform/run.sh; then pass "shellcheck sh"; else fail "shellcheck sh"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "four services" "client db opnform redis" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "only the opnform front publishes a port" "opnform" "$(jq -r '[.services | to_entries[] | select(.value.ports) | .key] | join(" ")' <<<"$cfg")"
assert_eq "the port binds to loopback" "127.0.0.1" "$(jq -r '[.services.opnform.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the published port is opnform's \$PORT" "$(jq -r '.services.opnform.environment.PORT' <<<"$cfg")" "$(jq -r '[.services.opnform.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "the storage volume is mounted" "/usr/share/nginx/html/storage" "$(jq -r '[.services.opnform.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "the database volume is mounted at the parent dir" "/var/lib/postgresql" "$(jq -r '[.services.db.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "PGDATA lives inside the volume" "/var/lib/postgresql/pgdata" "$(jq -r '.services.db.environment.PGDATA' <<<"$cfg")"
assert_eq "redis keeps an append-only file in its volume" "/data" "$(jq -r '[.services.redis.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_contains "postgres is pinned by tag and digest" '^postgres:16\.[0-9]*@sha256:[0-9a-f]\{64\}$' "$(jq -r '.services.db.image' <<<"$cfg")"
assert_contains "redis (Valkey) is pinned by tag and digest" '^valkey/valkey:8\.[0-9.]*-alpine@sha256:[0-9a-f]\{64\}$' "$(jq -r '.services.redis.image' <<<"$cfg")"
assert_contains "the client is pinned by tag and digest" '^jhumanj/opnform-client:[0-9.]*@sha256:[0-9a-f]\{64\}$' "$(jq -r '.services.client.image' <<<"$cfg")"
assert_eq "the client reaches the API through the opnform front" "http://opnform:8080/api" "$(jq -r '.services.client.environment.NUXT_PRIVATE_API_BASE' <<<"$cfg")"
assert_eq "the client and API share the server-side secret" "$(jq -r '.services.opnform.environment.FRONT_API_SECRET' <<<"$cfg")" "$(jq -r '.services.client.environment.NUXT_API_SECRET' <<<"$cfg")"
assert_eq "JWTs stay bound to the User-Agent" "false" "$(jq -r '.services.opnform.environment.JWT_SKIP_IP_UA_VALIDATION' <<<"$cfg")"
assert_contains "the compose admin password is a placeholder" 'local-test-only' "$(jq -r '.services.opnform.environment.ADMIN_PASSWORD' <<<"$cfg")"
assert_contains "the compose DB password is a placeholder" 'local-test-only' "$(jq -r '.services.db.environment.POSTGRES_PASSWORD' <<<"$cfg")"

section "images"
df=images/opnform/Dockerfile
assert_contains "API base pinned by tag and digest" '^ARG OPNFORM_API_IMAGE=jhumanj/opnform-api:[0-9.]*@sha256:[0-9a-f]\{64\}$' "$(grep '^ARG OPNFORM_API_IMAGE=' "$df")"
a_tag=$(grep '^ARG OPNFORM_API_IMAGE=' "$df" | sed 's/.*:\([0-9.]*\)@.*/\1/')
c_tag=$(jq -r '.services.client.image' <<<"$cfg" | sed 's/.*:\([0-9.]*\)@.*/\1/')
assert_eq "API and client are the same release" "$a_tag" "$c_tag"
assert_contains "self-hosted mode (first user only) is on" 'SELF_HOSTED=true' "$(cat "$df")"
assert_contains "the stock upstream entrypoint still runs" 'exec /usr/local/bin/opnform-entrypoint /usr/local/bin/opnform-railway-run' "$(cat images/opnform/entrypoint.sh)"
assert_contains "php-fpm listens on loopback only" 'listen = 127.0.0.1:9000' "$(cat images/opnform/php-fpm-loopback.conf)"

section "first-user bootstrap"
b=images/opnform/bootstrap-admin.php
assert_contains "the bootstrap only runs on an empty users table" 'User::count()' "$(cat "$b")"
assert_contains "it uses the app's own register endpoint" "Request::create('/register', 'POST'" "$(cat "$b")"
assert_contains "exception traces never include the request body" "zend.exception_ignore_args', '1'" "$(cat "$b")"
assert_not_contains "the password is never printed" '$password"' "$(grep -n 'out(' "$b")"
r=images/opnform/run.sh
bl=$(grep -n 'bootstrap-admin.php' "$r" | head -1 | cut -d: -f1); nl=$(grep -n "start nginx" "$r" | head -1 | cut -d: -f1)
[ "$bl" -lt "$nl" ] && pass "the first user exists before nginx listens publicly" || fail "nginx starts before the bootstrap"

section "nginx"
conf=images/opnform/nginx.conf.template
assert_contains "the client host is resolved at request time" 'proxy_pass http://$opnform_client;' "$(cat "$conf")"
assert_contains "a runtime resolver is configured" 'resolver @RESOLVER@ valid=10s;' "$(cat "$conf")"
assert_contains "IPv6 resolvers are bracketed" 'ns="\[$ns\]"' "$(cat "$r")"
assert_contains "nginx listens dual-stack (Railway private network is IPv6)" 'listen \[::\]:@PORT@ ipv6only=off;' "$(cat "$conf")"
assert_contains "the /api prefix is stripped like upstream" 'fastcgi_param REQUEST_URI $api_uri;' "$(cat "$conf")"
assert_contains "dot-files are denied" 'deny all;' "$(cat "$conf")"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
