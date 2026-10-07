# Security

## What the template enforces

- **No first-run race.** The first user (workspace admin, and instance admin through `ADMIN_EMAILS`) is created
  from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` before anything listens publicly. OpnForm self-hosted mode
  then refuses public registration (`Registration is not allowed.`); new users join by invitation only.
- **Generated secrets:** `APP_KEY`, `JWT_SECRET`, `FRONT_API_SECRET`, `ADMIN_PASSWORD` and the PostgreSQL password
  are Railway-generated per deploy.
- **Private by default:** only the nginx front has a domain. php-fpm listens on loopback; PostgreSQL, Redis and the
  Nuxt client are on Railway's private network.
- **JWT binding:** `JWT_SKIP_IP_UA_VALIDATION=false` (upstream default) keeps tokens bound to the browser's
  User-Agent.
- The bootstrap never prints the password, and disables exception arguments so a failure cannot log the request
  body.

## What you should do

- Sign in, then change the password (Settings → Password) if you like; the variable is only read on an empty DB.
- Configure SMTP (`MAIL_*`) if you want password resets, invitations and submission notifications by email; the
  template defaults to `MAIL_MAILER=log`.
- Back up the `db` volume (forms and responses) and the `opnform` storage volume (uploads, OAuth keys).
- Custom code in forms stays disabled (`CUSTOM_CODE_ENABLE_SELF_HOSTED` unset, upstream default).

## Reporting

Template issues: https://github.com/youssefsiam38/opnform-railway/issues. OpnForm vulnerabilities: follow
upstream's SECURITY.md (https://github.com/JhumanJ/OpnForm/security).
