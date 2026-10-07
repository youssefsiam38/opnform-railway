#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Local end-to-end smoke test against a fresh compose stack (the wrapper image must already be built).
# Covers: first user created from env, closed sign-up, the private client, auth gates, admin login, the core form
# flows (create a form -> anonymous public submission -> admin reads the response), a client recreate behind the
# nginx front, and that the bootstrap does not run twice.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.tok
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "start-up"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || { compose logs --tail 80 opnform client >&2; die "OpnForm never became reachable"; }
pass "the API (PostgreSQL + Redis) and the web app answer through the nginx front"
logs=$(compose logs --no-color opnform 2>&1)
assert_contains "the first user was created at start-up" "first user created for $OF_ADMIN_EMAIL" "$logs"
assert_not_contains "the admin password never reaches the logs" "$OF_ADMIN_PASSWORD" "$(compose logs --no-color 2>&1)"
assert_contains "upstream migrations ran" "Running DB Migrations" "$logs"

section "network exposure"
assert_eq "only the opnform front publishes a port" "opnform" \
  "$(compose config --format json | jq -r '[.services | to_entries[] | select(.value.ports) | .key] | join(" ")')"
assert_eq "php-fpm is not reachable from other containers" "closed" \
  "$(compose exec -T client node -e 'const s=require("net").connect(9000,"opnform");s.on("connect",()=>{console.log("open");process.exit()});s.on("error",()=>{console.log("closed");process.exit()});setTimeout(()=>{console.log("closed");process.exit()},5000)' | tr -d '\r')"

section "security gates"
security_gates

section "admin"
if login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in"; else fail "admin login: HTTP $CODE"; fi
req "$ADMIN" GET /api/user
assert_eq "the session is the admin" "$OF_ADMIN_EMAIL" "$(jq -r .email <<<"$BODY")"
req "$ADMIN" GET /api/user "" -A "some-other-browser"
assert_eq "the JWT is refused from another User-Agent" "401" "$CODE"
login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN" || die "admin re-login failed"

section "form flows"
TAG=$(rand)
create_form "$ADMIN" "$TAG"
submit_answer "$FORM_SLUG" "$TAG"
verify_submission "$ADMIN" "$FORM_ID" "$TAG"

section "client recreated behind the front"
compose up -d --force-recreate --no-deps client >/dev/null 2>&1 || die "client recreate failed"
wait_for_code "$APP_URL/login" 200 300 || die "the web app never came back after recreating the client"
pass "nginx re-resolves the recreated client"

section "opnform restarted"
compose restart opnform >/dev/null 2>&1 || die "opnform restart failed"
wait_for_app 300 || die "OpnForm never came back"
logs=$(compose logs --no-color opnform 2>&1 | tail -n 300)
assert_contains "the first-user bootstrap does not run again" "first-user bootstrap skipped" "$logs"
assert_contains "the Passport keys are reused from the storage volume" "Reusing Passport keys from storage" "$logs"
if login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in after the restart"; else fail "admin login after restart: HTTP $CODE"; fi
verify_form "$ADMIN" "$FORM_SLUG" "$TAG"
verify_submission "$ADMIN" "$FORM_ID" "$TAG"

section "logout"
req "$ADMIN" POST /api/logout '{}'
assert_eq "logout" "200" "$CODE"
req "$ADMIN" GET /api/user
assert_eq "the token is revoked" "401" "$CODE"

summary
