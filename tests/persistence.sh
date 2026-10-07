#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2119
# Persistence: data written before `compose down` (volumes kept) is still there after `compose up`, the admin can
# still sign in, and the first-user bootstrap does not run again. Mirrors a Railway redeploy of every service.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.tok
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "write"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "OpnForm never became reachable"
login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN" || die "admin login failed: HTTP $CODE"
TAG=$(rand)
create_form "$ADMIN" "$TAG"
submit_answer "$FORM_SLUG" "$TAG"
verify_submission "$ADMIN" "$FORM_ID" "$TAG"

section "recreate every service, keep volumes"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "OpnForm never came back"
pass "the stack came back"
logs=$(compose logs --no-color opnform 2>&1)
assert_contains "the first-user bootstrap is skipped on an existing database" "users exist (1); first-user bootstrap skipped" "$logs"
assert_contains "the Passport keys are reused from the storage volume" "Reusing Passport keys from storage" "$logs"

section "verify"
if login "$OF_ADMIN_EMAIL" "$OF_ADMIN_PASSWORD" "$ADMIN"; then pass "admin still signs in"; else fail "admin login: HTTP $CODE"; fi
verify_form "$ADMIN" "$FORM_SLUG" "$TAG"
verify_submission "$ADMIN" "$FORM_ID" "$TAG"
req "" GET /api/content/feature-flags
assert_eq "setup is still not required" "false" "$(jq -r .setup_required <<<"$BODY")"

summary
