# Marketplace audit

| Item | Result |
|------|--------|
| Upstream | OpnForm v2.5.0, active (releases every 1-3 weeks), official multi-arch images |
| Licence | AGPL-3.0 core. `api/app/Enterprise` is under the OpnForm Enterprise licence; upstream docs: core self-hosted use needs no licence, Enterprise features stay locked until a key is activated. Images are referenced unmodified from upstream's registry, not redistributed. Verdict: shippable. |
| Brand | Name used descriptively; generic icon; not-affiliated note |
| Gap | No OpnForm template on the marketplace (gapscan 2026-10-07) |
| Self-hosting | Everything bundled: PostgreSQL 16, Valkey 8, API, client. No external service required. |
| Security | First-run admin race closed (first user created from env before listening); registration then invite-only; php-fpm loopback; DB/Valkey/client private; generated secrets |
| Deploy inputs | `ADMIN_EMAIL` (required) |
| Tests | static 43, smoke 38, persistence 20, live HTTPS e2e (railway-smoke) incl. redeploy |

Verdict: **SHIPPABLE** with a thin wrapper (nginx front + worker/scheduler + first-user bootstrap).
