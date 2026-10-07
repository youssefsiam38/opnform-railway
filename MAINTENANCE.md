# Maintenance

## Bumping OpnForm

1. Read the upstream release notes and diff `docker/php-fpm-entrypoint`, `docker/nginx.conf` and
   `api/.env.docker`/`client/.env.docker` for new required variables or routes.
2. Update the API digest in `images/opnform/Dockerfile` and the client digest in `compose.yaml` (same release).
3. `tests/static.sh && docker compose build && tests/smoke.sh && tests/persistence.sh`.
4. Commit, tag `vX.Y.Z` → `publish-image` builds, re-tests and pushes `ghcr.io/youssefsiam38/opnform-railway`.
5. Point the template's `opnform` image at the new wrapper digest and the `client` image at the new client digest
   (`_audit/spec_opnform.py` → `tplkit.patch_template`), deploy a clean-room copy and run `tests/railway-smoke.sh`.

## Rebuilding the template from scratch

`_audit/spec_opnform.py` + `tplkit.skeleton` → `railway templates create` → `tplkit.patch_template` → verify.

## Gotchas

- `JWT_SECRET` must be at least 32 characters (HS256 key length), or every login returns 500.
- The register endpoint's two throttles share one key, so a few quick register/login attempts from one IP get 429
  for a minute; tests retry on 429.
- The wrapper must not start nginx before the first-user bootstrap, or the setup-mode registration is public.
- Railway rejects health-check paths with a dot (`/favicon.ico`); the private client has no health check, the `opnform` front checks `/api/healthcheck`.
