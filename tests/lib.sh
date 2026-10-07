#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2034,SC2120
# Shared helpers for opnform-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, counts, and pass/fail results are printed.

: "${APP_URL:=http://127.0.0.1:${OPNFORM_TEST_PORT:-18290}}"
: "${TEST_TIMEOUT:=600}"
# Do not inherit a generic ADMIN_PASSWORD from the caller's shell; tests use their own names.
: "${OF_ADMIN_EMAIL:=${OPNFORM_TEST_ADMIN_EMAIL:-admin@example.com}}"
: "${OF_ADMIN_PASSWORD:=${OPNFORM_TEST_ADMIN_PASSWORD:-local-test-only-Admin-pass1!}}"
# OpnForm binds its JWTs to the browser's User-Agent; send one fixed UA everywhere.
UA="opnform-railway-tests/1.0"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
chmod 700 "$TEST_TMP"
export TEST_TMP
_PASS=0; _FAIL=0
CODE=""; BODY=""

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -qF -- "$2" <<<"$3"; then fail "$1: found forbidden value"; else pass "$1"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 -A "$UA" "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

# /api/healthcheck checks PostgreSQL and Redis through php-fpm; the web app (Nuxt) is up when /login renders.
wait_for_app() {
  wait_for_code "$APP_URL/api/healthcheck" 200 "${1:-$TEST_TIMEOUT}" && wait_for_code "$APP_URL/login" 200 "${1:-$TEST_TIMEOUT}"
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

# req TOKENFILE METHOD PATH [JSON-or-@file] [extra curl args...] -> sets CODE and BODY. TOKENFILE may be "" (anonymous).
# The bearer token is passed to curl through a header file, never argv.
req() {
  local tok=$1 method=$2 path=$3 data=${4:-}
  shift 3; [ $# -gt 0 ] && shift
  local args=(-s -o "$TEST_TMP/body" -w '%{http_code}' --max-time 60 -X "$method" -A "$UA" -H 'Accept: application/json')
  if [ -n "$tok" ]; then
    ( umask 077; printf 'Authorization: Bearer %s\n' "$(cat "$tok")" >"$TEST_TMP/auth.hdr" )
    args+=(-H "@$TEST_TMP/auth.hdr")
  fi
  [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "$data")
  CODE=$(curl "${args[@]}" "$@" "$APP_URL$path" || true)
  BODY=$(cat "$TEST_TMP/body" 2>/dev/null || true)
  rm -f "$TEST_TMP/auth.hdr"
}

# Retries a request while Laravel's rate limiter answers 429 (register/login are throttled per client IP).
req_retry_429() {
  local i
  for i in $(seq 1 12); do
    req "$@"
    [ "$CODE" = "429" ] || return 0
    sleep 10
  done
}

# login EMAIL PASSWORD TOKENFILE -> 0 on success (JWT in TOKENFILE, mode 600). The body goes through a mode-600 file.
login() {
  rm -f "$3"
  ( umask 077; jq -nc --arg e "$1" --arg p "$2" '{email:$e, password:$p}' >"$TEST_TMP/login.json" )
  req_retry_429 "" POST /api/login "@$TEST_TMP/login.json"
  rm -f "$TEST_TMP/login.json"
  [ "$CODE" = "200" ] || return 1
  ( umask 077; jq -r .token <<<"$BODY" >"$3" )
  [ -s "$3" ] && [ "$(cat "$3")" != null ]
}

rand() { head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

NAME_FIELD=11111111-1111-4111-8111-111111111111
EMAIL_FIELD=22222222-2222-4222-8222-222222222222

# create_form TOKENFILE TAG -> creates a public two-field form in the user's workspace. Sets WORKSPACE_ID, FORM_ID, FORM_SLUG.
create_form() {
  local tok=$1 tag=$2
  req "$tok" GET /api/open/workspaces
  assert_eq "list workspaces" "200" "$CODE"
  WORKSPACE_ID=$(jq -r '.[0].id' <<<"$BODY")
  [ -n "$WORKSPACE_ID" ] && [ "$WORKSPACE_ID" != null ] && pass "the admin has a workspace" || fail "no workspace"
  jq -nc --argjson w "$WORKSPACE_ID" --arg t "Railway form $tag" --arg n "$NAME_FIELD" --arg e "$EMAIL_FIELD" '{
      workspace_id:$w, title:$t, visibility:"public", language:"en", theme:"default", presentation_style:"classic",
      width:"centered", size:"md", border_radius:"small", dark_mode:"auto", color:"#3B82F6", uppercase_labels:false,
      no_branding:false, transparent_background:false, submitted_text:"Thanks!",
      properties:[{id:$n, name:"Your name", type:"text", required:true},
                  {id:$e, name:"Email", type:"email", required:false}]}' >"$TEST_TMP/form.json"
  req "$tok" POST /api/open/forms "@$TEST_TMP/form.json"
  assert_eq "create a form" "200" "$CODE"
  FORM_ID=$(jq -r '.form.id' <<<"$BODY"); FORM_SLUG=$(jq -r '.form.slug' <<<"$BODY")
  [ -n "$FORM_SLUG" ] && [ "$FORM_SLUG" != null ] && pass "the form has a public slug" || fail "no form slug"
  req "$tok" GET "/api/open/workspaces/$WORKSPACE_ID/forms"
  assert_eq "the form is listed in the workspace" "1" "$(jq --arg s "$FORM_SLUG" '[(.data // .)[] | select(.slug==$s)] | length' <<<"$BODY")"
}

# submit_answer SLUG TAG -> an anonymous visitor opens and submits the public form.
submit_answer() {
  local slug=$1 tag=$2
  req "" GET "/api/forms/$slug"
  assert_eq "anonymous visitor loads the public form" "200" "$CODE"
  assert_eq "the public form has two fields" "2" "$(jq '.properties | length' <<<"$BODY")"
  assert_contains "the public form page renders (SSR via the private API)" "Railway form $tag" "$(curl -s --max-time 60 -A "$UA" "$APP_URL/forms/$slug")"
  req_retry_429 "" POST "/api/forms/$slug/answer" "$(jq -nc --arg n "$NAME_FIELD" --arg e "$EMAIL_FIELD" --arg v "Visitor $tag" \
    '{($n):$v, ($e):"visitor@example.com"}')"
  assert_eq "anonymous visitor submits the form" "200" "$CODE"
  assert_eq "the submission is accepted" "success" "$(jq -r .type <<<"$BODY")"
}

# verify_submission TOKENFILE FORM_ID TAG -> the admin reads the response back (stored by the queue worker).
verify_submission() {
  local tok=$1 id=$2 tag=$3 i got=""
  for i in $(seq 1 20); do
    req "$tok" GET "/api/open/forms/$id/submissions"
    got=$(jq -r --arg n "$NAME_FIELD" --arg v "Visitor $tag" '[.data[]?.data | select(.[$n]==$v)] | length' <<<"$BODY")
    [ "$got" = "1" ] && break
    sleep 3
  done
  assert_eq "the admin reads the response back" "1" "$got"
  assert_eq "the response keeps the email answer" "visitor@example.com" \
    "$(jq -r --arg n "$NAME_FIELD" --arg e "$EMAIL_FIELD" --arg v "Visitor $tag" '[.data[]?.data | select(.[$n]==$v) | .[$e]][0]' <<<"$BODY")"
}

# verify_form TOKENFILE SLUG TAG -> the form still exists and is still public.
verify_form() {
  local tok=$1 slug=$2 tag=$3
  req "" GET "/api/forms/$slug"
  assert_eq "the public form survived" "Railway form $tag" "$(jq -r .title <<<"$BODY")"
}

# security_gates -> anonymous access is refused, sign-up is closed, wrong passwords are rejected.
security_gates() {
  req "" GET /api/user
  assert_eq "anonymous /api/user is refused" "401" "$CODE"
  req "" GET /api/open/workspaces
  assert_eq "anonymous /api/open/workspaces is refused" "401" "$CODE"
  req "" GET /api/content/feature-flags
  assert_eq "the instance is self-hosted" "true" "$(jq -r .self_hosted <<<"$BODY")"
  assert_eq "the first-run setup is already done" "false" "$(jq -r .setup_required <<<"$BODY")"
  ( umask 077; jq -nc --arg e "intruder-$(rand)@example.org" \
      '{name:"Intruder", email:$e, password:"Intruder-pass1!", password_confirmation:"Intruder-pass1!", hear_about_us:"x", agree_terms:true}' >"$TEST_TMP/reg.json" )
  req_retry_429 "" POST /api/register "@$TEST_TMP/reg.json"
  assert_eq "public sign-up is closed" "400" "$CODE"
  assert_contains "the server says registration is not allowed" "Registration is not allowed" "$BODY"
  if login "intruder@example.org" "Intruder-pass1!" "$TEST_TMP/intruder.tok"; then
    fail "the would-be intruder can sign in"
  else
    assert_eq "the would-be intruder cannot sign in" "422" "$CODE"
  fi
  if login "$OF_ADMIN_EMAIL" "not-the-Password1!" "$TEST_TMP/wrong.tok"; then
    fail "a wrong admin password is accepted"
  else
    assert_eq "a wrong admin password is rejected" "422" "$CODE"
  fi
}
