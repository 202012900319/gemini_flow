# Project Status

## Current Focus

Local deployment and acceptance verification of `TheSmallHanCat/flow2api`.

## Latest Meaningful Changes

- Created local runtime config from `config/setting_example.toml`.
- Deployed the service with `docker-compose.local.yml` using a local-source image.
- Deployed `genz27/flow_captcha_service` locally in standalone headed-browser mode at `http://127.0.0.1:8060`.
- Switched Flow2API captcha mode to `remote_browser` and connected it to the local captcha service.
- Verified a real Gemini-compatible image generation request succeeds through the remote-browser captcha path.
- Fixed two source-test regressions in `src/services/flow_client.py`:
  - API captcha token retrieval now tolerates test/lightweight instances that bypass `__init__`.
  - Video status normalization preserves `fifeUrl` in operation metadata.
- Expanded the acceptance test plan for remote-browser captcha and image-generation verification.

## Current State

Working locally at `http://localhost:38000`.

Flow2API is running with one active token. `flow_captcha_service` is healthy in standalone mode and Flow2API reports `captcha_method: remote_browser`, `remote_browser_configured: true`.

Admin login uses the default local credentials `admin` / `admin`; this should be changed before any non-local exposure. The runtime API key is currently database-backed and may differ from `config/setting.toml` if changed through the admin UI.

## Verification Status

- Docker local-source build: passed.
- Full mounted source tests in Docker dependency environment: `40 passed`.
- Flow2API health endpoint: passed, `backend_running: true`, `captcha_method: remote_browser`, `remote_browser_configured: true`.
- `flow_captcha_service` health endpoint: passed, `success: true`, `role: standalone`.
- Metrics endpoint: passed.
- Model list auth behavior: unauthenticated `401`; runtime database API key returns `200` with 169 models.
- Gemini-compatible image generation: passed on `/models/gemini-3.1-flash-image-landscape:generateContent`, returned one candidate with inline image data.
- Remote captcha handoff: passed; captcha service logs show `/api/v1/solve`, token acquisition, and `/finish`.
- Admin login and stats API: passed.

## Deferred Acceptance

Still pending broader account-dependent checks:

- ST to AT conversion and AT refresh.
- Image generation through the OpenAI-compatible `/v1/chat/completions` route.
- Video generation and polling through OpenAI-compatible and Gemini-compatible routes.
- Token balance refresh.
- YesCaptcha/CapMonster/EzCaptcha/CapSolver or browser/personal captcha modes.

## Useful Commands

```powershell
docker compose -f docker-compose.local.yml ps
docker compose -f docker-compose.local.yml logs -f flow2api
docker compose -f docker-compose.local.yml down
docker compose -f docker-compose.local.yml up -d --build
curl.exe -fsS http://127.0.0.1:38000/health
curl.exe -fsS http://127.0.0.1:8060/api/v1/health
```
