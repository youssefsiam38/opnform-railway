# OpnForm on Railway

One-click [Railway](https://railway.com) template for [OpnForm](https://github.com/JhumanJ/OpnForm), the open-source
Typeform / Google Forms alternative: build forms with a drag-and-drop editor, share a public link or embed them, and
read the responses in a table.

Community-maintained. Not affiliated with or endorsed by OpnForm; the icon is generic, not the OpnForm logo.

## What you get

| Service   | Image | Public | Volume |
|-----------|-------|--------|--------|
| `opnform` | `ghcr.io/youssefsiam38/opnform-railway` (wrapper `FROM jhumanj/opnform-api`, digest-pinned) | yes (8080) | `/usr/share/nginx/html/storage` |
| `client`  | `jhumanj/opnform-client` (stock, digest-pinned) | no | none |
| `db`      | `postgres:16.15` (digest-pinned) | no | `/var/lib/postgresql` |
| `redis`   | `valkey/valkey:8.1.10-alpine` (Redis-compatible, digest-pinned) | no | `/data` |

`opnform` runs the stock OpnForm API (Laravel/php-fpm, its own entrypoint: migrations, Passport keys, cache warm-up)
plus the queue worker, the scheduler and an nginx front that serves `/api` through php-fpm and proxies the rest to
the private Nuxt `client`, exactly like upstream's docker-compose ingress.

## Deploy

1. Click deploy and enter your email as `ADMIN_EMAIL` (on `opnform`).
2. Wait for all four services to turn green (the first start runs the database migrations).
3. Copy `ADMIN_PASSWORD` from the `opnform` service's Variables and sign in at the `opnform` domain.

## Security

OpnForm in self-hosted mode lets the **first** visitor register and become the instance admin; after that,
registration is invite-only. On a fresh public URL that is a race. This template creates the first user from
`ADMIN_EMAIL` + a generated `ADMIN_PASSWORD` before nginx starts listening, so the public sign-up is closed from the
first request. php-fpm listens on loopback only; PostgreSQL, Redis and the Nuxt client are private. See
[SECURITY.md](SECURITY.md).

## Licence

Template files: MIT ([LICENSE](LICENSE)). OpnForm: AGPL-3.0, except `api/app/Enterprise` (OpnForm Enterprise licence,
features locked without a paid licence key); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Repository layout

| Path | Purpose |
|------|---------|
| `images/opnform/` | Wrapper: Dockerfile, nginx config, entrypoint/run scripts, first-user bootstrap |
| `compose.yaml` | Local topology mirroring the Railway services |
| `tests/` | `static.sh`, `smoke.sh`, `persistence.sh`, `railway-smoke.sh` (live HTTPS e2e) |
| `marketplace/OVERVIEW.md` | Marketplace page |
| `.github/workflows/` | CI tests; image publish on `vX.Y.Z` tags |

## Local development

```bash
tests/static.sh                 # no build: shape, pins, security defaults
docker compose build
tests/smoke.sh                  # first user, gates, create form -> public submit -> read responses
tests/persistence.sh            # data survives down/up with volumes kept
APP_URL=https://<domain> OF_ADMIN_EMAIL=<email> OF_ADMIN_PASSWORD_FILE=<file> tests/railway-smoke.sh
```
