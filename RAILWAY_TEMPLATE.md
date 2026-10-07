# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | OpnForm |
| Code | `opnform` |
| Template id | `837ad7d8-e8bb-4468-8aed-a532ec1f58dc` |
| Deploy URL | https://railway.com/deploy/opnform |
| Category | Other |
| Card description | Open-source form builder (Typeform alternative) with PostgreSQL |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Every image is pinned by tag and digest (see `UPSTREAM.md`).

## Services

### `db`

| Field | Value |
|---|---|
| Source | `postgres:16.15@sha256:65b16a8b326e0cfbdf33fa7e783f2a0cb352a61448616ccccfd616ef42aa0f65` |
| Public domain | none |
| Volume | `/var/lib/postgresql` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `POSTGRES_USER` | `opnform` |
| `POSTGRES_DB` | `opnform` |
| `POSTGRES_PASSWORD` | generated, alnum40 |
| `PGDATA` | `/var/lib/postgresql/pgdata` |

### `redis`

| Field | Value |
|---|---|
| Source | `valkey/valkey:8.1.10-alpine@sha256:081c2f5cb575efc901aa80ff9cdbd1ec6a301682fd35e1ebb4b0990a4a4a8507` |
| Public domain | none |
| Volume | `/data` |
| Start command | `valkey-server --appendonly yes --protected-mode no` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|

### `opnform`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/opnform-railway:1.0.0@sha256:549cd20a56c8f0f65b137d6363eac37081b0e4fbab6c2aa34af9632c0f035992` |
| Public domain | target port 8080 |
| Volume | `/usr/share/nginx/html/storage` |
| Healthcheck | `/api/healthcheck`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `ADMIN_EMAIL` | required input, no default |
| `ADMIN_PASSWORD` | generated, alnum20 followed by `Aa1!` |
| `ADMIN_NAME` | `Admin` |
| `ADMIN_EMAILS` | `${{ADMIN_EMAIL}}` |
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `FRONT_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `APP_KEY` | generated, alnum32 |
| `JWT_SECRET` | generated, alnum64 |
| `FRONT_API_SECRET` | generated, alnum48 |
| `JWT_SKIP_IP_UA_VALIDATION` | `false` |
| `DB_HOST` | `${{db.RAILWAY_PRIVATE_DOMAIN}}` |
| `DB_PORT` | `5432` |
| `DB_DATABASE` | `${{db.POSTGRES_DB}}` |
| `DB_USERNAME` | `${{db.POSTGRES_USER}}` |
| `DB_PASSWORD` | `${{db.POSTGRES_PASSWORD}}` |
| `REDIS_HOST` | `${{redis.RAILWAY_PRIVATE_DOMAIN}}` |
| `REDIS_PORT` | `6379` |
| `CLIENT_UPSTREAM` | `${{client.RAILWAY_PRIVATE_DOMAIN}}:3000` |
| `PORT` | `8080` |
| `MAIL_MAILER` | `log` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |
| `MAIL_HOST` | optional, unset |
| `MAIL_PORT` | optional, unset |
| `MAIL_USERNAME` | optional, unset |
| `MAIL_PASSWORD` | optional, unset |
| `MAIL_ENCRYPTION` | optional, unset |
| `MAIL_FROM_ADDRESS` | optional, unset |
| `MAIL_FROM_NAME` | optional, unset |
| `OPEN_AI_API_KEY` | optional, unset |
| `OPNFORM_ANONYMOUS_TELEMETRY_DISABLED` | optional, unset |
| `H_CAPTCHA_SITE_KEY` | optional, unset |
| `H_CAPTCHA_SECRET_KEY` | optional, unset |

### `client`

| Field | Value |
|---|---|
| Source | `jhumanj/opnform-client:2.5.0@sha256:8862ee89453fdf10ec1c652b94a2dfb28abd16fe0af1d67e982bcc780dcca68e` |
| Public domain | none |
| Volume | none |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `PORT` | `3000` |
| `NUXT_PUBLIC_APP_URL` | `https://${{opnform.RAILWAY_PUBLIC_DOMAIN}}` |
| `NUXT_PUBLIC_API_BASE` | `https://${{opnform.RAILWAY_PUBLIC_DOMAIN}}/api` |
| `NUXT_PRIVATE_API_BASE` | `http://${{opnform.RAILWAY_PRIVATE_DOMAIN}}:8080/api` |
| `NUXT_API_SECRET` | `${{opnform.FRONT_API_SECRET}}` |
| `NUXT_PUBLIC_ENV` | `production` |
| `NUXT_PUBLIC_H_CAPTCHA_SITE_KEY` | optional, unset |

## Notes

- `opnform` is a wrapper `FROM jhumanj/opnform-api:2.5.0`: nginx (upstream ingress config), php-fpm on loopback, queue
  worker and scheduler in one container so they share the storage volume. The stock upstream entrypoint runs first.
- The first user is created in-process through the app's own `POST /register` before nginx listens; self-hosted
  mode then refuses public registration.
- The private `client` has no health check (Railway rejects `/favicon.ico` as a path); `opnform` checks
  `/api/healthcheck` (PostgreSQL + Valkey).
- `JWT_SECRET` must be at least 32 characters; the wrapper refuses to start otherwise.
- Live e2e (2026-10-07): admin login, refused sign-up/anonymous API, create form, anonymous submit, read responses;
  all survived a redeploy of every service.
