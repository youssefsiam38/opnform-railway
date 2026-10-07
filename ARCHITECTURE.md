# Architecture

```
            Railway edge (HTTPS)
                    |
                    v  :8080
  +------------------------------------------+        private network (IPv6)
  | opnform (wrapper)                        |  ---->  client  (Nuxt SSR, :3000)
  |  nginx [::]:8080                         |  <----  (SSR calls http://opnform.railway.internal:8080/api
  |   /api, /open, /forms/assets, /local/temp|          with the shared FRONT_API_SECRET)
  |     -> php-fpm 127.0.0.1:9000 (Laravel)  |
  |   everything else -> client:3000         |  ---->  db     (PostgreSQL 16, volume /var/lib/postgresql)
  |  php artisan queue:work                  |  ---->  redis  (cache, queue, sessions; volume /data)
  |  php artisan schedule:work               |
  |  volume: /usr/share/nginx/html/storage   |
  +------------------------------------------+
```

## Why a wrapper, and why this shape

Upstream ships two images (API = php-fpm on FastCGI port 9000, client = Nuxt) and an `nginx` ingress whose config
is a bind-mounted file. Railway cannot bind-mount files, and the API, worker and scheduler need the same storage
directory (uploads, Passport keys), but a Railway volume belongs to one service. So the wrapper is
`FROM jhumanj/opnform-api` plus:

- `nginx`, configured like upstream's `docker/nginx.conf` (same `/api` prefix stripping and routes), listening
  dual-stack so the client can reach it over Railway's IPv6 private network, with a runtime `resolver` so a
  redeployed client is found again;
- php-fpm restricted to `127.0.0.1:9000`;
- the queue worker and scheduler as sibling processes; if any process exits, the container exits and Railway
  restarts it;
- a first-user bootstrap (below).

The upstream entrypoint (`opnform-entrypoint`) runs unmodified: our entrypoint validates the required variables
and `exec`s it with our run script as the command, so upstream's "api" role does the DB wait, migrations, storage
link, Passport keys and `artisan optimize` first.

## First user

`bootstrap-admin.php` boots Laravel in-process and, only if the `users` table is empty, sends the app's own
`POST /register` through the HTTP kernel (no network, nothing on argv) with `ADMIN_NAME`/`ADMIN_EMAIL`/
`ADMIN_PASSWORD`. OpnForm's self-hosted rule ("registration allowed only while no user exists") then closes sign-up.
nginx is started only after this, so nobody can reach the setup-mode registration first.

## Client IPs, HTTPS

nginx takes the client IP from `X-Forwarded-For` (trusting only private/loopback hops) and passes it as
`REMOTE_ADDR`, so Laravel's per-IP throttles see real visitors. `HTTPS=on` is passed to PHP when the edge says
`X-Forwarded-Proto: https`. Forwarded headers are not passed to Laravel (no `TRUSTED_PROXIES` needed).
