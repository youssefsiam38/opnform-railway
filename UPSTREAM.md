# Upstream

- Project: OpnForm, https://github.com/JhumanJ/OpnForm (AGPL-3.0; `api/app/Enterprise` under the OpnForm Enterprise
  licence)
- Release: v2.5.0 (commit 17a595d)
- Official images (Docker Hub, amd64 + arm64):
  - `jhumanj/opnform-api:2.5.0@sha256:8cf89fb82d0d3b9a2381edf4b95abf7a2bfb2f61c4cef4f14fea0b98a53016f2`
    (base of the wrapper, `images/opnform/Dockerfile`)
  - `jhumanj/opnform-client:2.5.0@sha256:8862ee89453fdf10ec1c652b94a2dfb28abd16fe0af1d67e982bcc780dcca68e`
- Bundled: `postgres:16.15@sha256:65b16a8b326e0cfbdf33fa7e783f2a0cb352a61448616ccccfd616ef42aa0f65`,
  `valkey/valkey:8.1.10-alpine@sha256:081c2f5cb575efc901aa80ff9cdbd1ec6a301682fd35e1ebb4b0990a4a4a8507`
- Wrapper: `ghcr.io/youssefsiam38/opnform-railway:1.0.0@WRAPPER_DIGEST`

## Refreshing a digest

```bash
curl -s https://hub.docker.com/v2/repositories/jhumanj/opnform-api/tags/<tag>/ | jq -r .digest
curl -s https://hub.docker.com/v2/repositories/jhumanj/opnform-client/tags/<tag>/ | jq -r .digest
```

API and client must be the same release (`tests/static.sh` checks it).
