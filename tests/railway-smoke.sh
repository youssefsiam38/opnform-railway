#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Live end-to-end test against a deployed template, over HTTPS.
#
#   APP_URL=https://<domain> OF_ADMIN_EMAIL=<ADMIN_EMAIL> OF_ADMIN_PASSWORD_FILE=<file holding ADMIN_PASSWORD> \
#     STATE_FILE=/tmp/opnform-live.state tests/railway-smoke.sh        # full run; records what it created
#   ... tests/railway-smoke.sh --verify                                 # after a redeploy: is it all still there?
#
# Never prints the password or tokens.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ -n "${APP_URL:-}" ] || { echo "set APP_URL=https://<your-domain>" >&2; exit 2; }
[ -n "${OF_ADMIN_EMAIL:-}" ] || { echo "set OF_ADMIN_EMAIL (the template's ADMIN_EMAIL)" >&2; exit 2; }
[ -n "${OF_ADMIN_PASSWORD_FILE:-}" ] && OF_ADMIN_PASSWORD=$(cat "$OF_ADMIN_PASSWORD_FILE")
[ -n "${OF_ADMIN_PASSWORD:-}" ] || { echo "set OF_ADMIN_PASSWORD_FILE" >&2; exit 2; }
APP_URL=${APP_URL%/}
: "${STATE_FILE:=$(mktemp)}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

ADMIN=$TEST_TMP/admin.tok
MODE=${1:-full}

section "edge"
assert_eq "HTTPS web app (login page)" "200" "$(http_code "$APP_URL/login")"
assert_eq "HTTPS API health (PostgreSQL + Redis)" "200" "$(http_code "$APP_URL/api/healthcheck")"
case "$APP_URL" in
  https://*) assert_eq "plain HTTP is redirected to HTTPS" "301" "$(http_code "http://${APP_URL#https://}/login")" ;;
esac

section "security gates"
security_gates

section "admin"
if login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in over HTTPS"; else fail "admin login: HTTP $CODE"; fi
req "$ADMIN" GET /api/user
assert_eq "the session is the admin" "$OF_ADMIN_EMAIL" "$(jq -r .email <<<"$BODY")"

if [ "$MODE" = "--verify" ]; then
  read -r TAG FORM_ID FORM_SLUG <"$STATE_FILE"
  [ -n "$TAG" ] || die "no state in $STATE_FILE"
  section "data survived"
  verify_form "$ADMIN" "$FORM_SLUG" "$TAG"
  verify_submission "$ADMIN" "$FORM_ID" "$TAG"
else
  section "form flows"
  TAG=$(rand)
  create_form "$ADMIN" "$TAG"
  submit_answer "$FORM_SLUG" "$TAG"
  verify_submission "$ADMIN" "$FORM_ID" "$TAG"
  printf '%s %s %s\n' "$TAG" "$FORM_ID" "$FORM_SLUG" >"$STATE_FILE"
fi

summary
