# Deploy and Host OpnForm on Railway

OpnForm is an open-source form builder, an alternative to Typeform, Tally and Google Forms: build forms with a
drag-and-drop editor, share them by link or embed them on your site, and collect and export the responses. This
template deploys a complete self-hosted OpnForm with PostgreSQL and a Redis-compatible cache; your admin account is
created from the email you enter and a generated password, so nobody can claim the instance first. It is a
community-maintained template and is not affiliated with the OpnForm project.

## About Hosting OpnForm

OpnForm is a Laravel API (php-fpm), a Nuxt web app, PostgreSQL and Redis, plus a queue worker and a scheduler.
Here the API, worker, scheduler and an nginx front run in one service (`opnform`, the only public one) so they share
one storage volume for uploads; the Nuxt app, PostgreSQL and Valkey (Redis-compatible) stay on Railway's private
network. Forms and responses live in PostgreSQL on a Railway volume.

Stock self-hosted OpnForm lets the first visitor register and become admin, which is a race on a fresh public URL.
This template creates the first user from your email and a generated password before the app starts listening;
after that OpnForm only accepts new users by invitation.

## Common Use Cases

- Contact, feedback, survey and event-registration forms you host yourself
- Lead capture and order forms embedded on your website, with conditional logic and file uploads
- Internal request forms (IT, HR, purchasing) with responses in a shared table and CSV export
- Replacing a paid Typeform or Tally plan while keeping the data in your own database

## Dependencies for OpnForm Hosting

- PostgreSQL 16: included, private, with its own volume
- Valkey 8 (Redis-compatible): included, private, for cache, queue and sessions
- Optional: an SMTP account for email notifications, invitations and password resets
- Optional: an OpenAI API key for AI form generation

### Deployment Dependencies

- OpnForm (AGPL-3.0): https://github.com/JhumanJ/OpnForm
- Template source, wrapper image and tests: https://github.com/youssefsiam38/opnform-railway

### Implementation Details

**First sign-in:** enter your email as `ADMIN_EMAIL` when deploying. When the services are green, copy
`ADMIN_PASSWORD` from the `opnform` service's Variables and sign in at the `opnform` domain. Invite teammates from
the workspace settings (the free community edition allows 2 users).

**What's configured for you:** the official OpnForm API and client images pinned by digest and unmodified; a small
wrapper on the API adding nginx (the upstream ingress config), the queue worker and the scheduler; generated
`APP_KEY`, `JWT_SECRET`, server-to-server secret, admin and database passwords; migrations on every start; a health
check on `/api/healthcheck` (PostgreSQL + Redis); public URLs set from the Railway domain.

**Optional settings** on `opnform`: `MAIL_MAILER=smtp` with `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`,
`MAIL_PASSWORD`, `MAIL_ENCRYPTION`, `MAIL_FROM_ADDRESS`; `OPEN_AI_API_KEY`; `OPNFORM_ANONYMOUS_TELEMETRY_DISABLED=true`
to opt out of upstream's anonymous usage statistics. If you add a custom domain, update `APP_URL`/`FRONT_URL` on
`opnform` and `NUXT_PUBLIC_APP_URL`/`NUXT_PUBLIC_API_BASE` on `client`.

Tested on a live deployment of this template over HTTPS: admin sign-in, refused sign-up and anonymous API access,
creating a form, an anonymous visitor submitting it, reading the response back, and all of it surviving a redeploy.

## Why Deploy OpnForm on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpnForm on Railway, you are one step closer to supporting a complete full-stack application with
minimal burden. Host your servers, databases, AI agents, and more on Railway.
