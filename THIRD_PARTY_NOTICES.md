# Third-party notices

| Component | Licence | Use |
|-----------|---------|-----|
| OpnForm API + client (`jhumanj/opnform-api`, `jhumanj/opnform-client`) | AGPL-3.0, except `api/app/Enterprise` (OpnForm Enterprise licence) | Official images, unmodified; the API image is the base of the wrapper |
| PostgreSQL (`postgres` official image) | PostgreSQL Licence | Unmodified |
| Valkey 8.1 (`valkey/valkey` image, Redis-compatible) | BSD-3-Clause | Unmodified, internal cache/queue/sessions |
| nginx (Alpine package) | BSD-2-Clause | Added to the wrapper |

OpnForm's source is at https://github.com/JhumanJ/OpnForm; licences are copied in `licenses/`. The wrapper does not
modify OpnForm code; it adds nginx, a process runner and a first-user bootstrap script (MIT, this repository).

**Enterprise code.** Upstream's images include `api/app/Enterprise` (OIDC SSO and other Enterprise features) under
the OpnForm Enterprise licence. Upstream documents that self-hosted OpnForm can be used without an Enterprise
licence for the core product and that Enterprise features stay locked until a licence key is activated. This
template activates nothing; the community edition allows up to 2 users without a licence.

**Trademarks.** "OpnForm" is used only to identify the software. This template is not affiliated with or endorsed by
OpnForm and does not use its logo.
