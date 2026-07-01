# Project Status

## Current Focus

Local deployment and acceptance verification of `TheSmallHanCat/flow2api`.

## Latest Meaningful Changes

- Added an optional Pic Batch Studio Docker Compose override. It keeps Pic Batch as a separate container in the same `gemini-flow-stack` project and persists its SQLite/image state under `data/pic-batch/`.
- Created local runtime config from `config/setting_example.toml`.
- Deployed the service with `docker-compose.local.yml` using a local-source image.
- Deployed `genz27/flow_captcha_service` locally in standalone headed-browser mode at `http://127.0.0.1:8060`.
- Switched Flow2API captcha mode to `remote_browser` and connected it to the local captcha service.
- Added and verified a unified Docker Compose stack plus PowerShell launcher so Flow2API and `flow_captcha_service` start in one Docker Desktop project.
- Verified a real Gemini-compatible image generation request succeeds through the remote-browser captcha path.
- Fixed two source-test regressions in `src/services/flow_client.py`:
  - API captcha token retrieval now tolerates test/lightweight instances that bypass `__init__`.
  - Video status normalization preserves `fifeUrl` in operation metadata.
- Expanded the acceptance test plan for remote-browser captcha and image-generation verification.

## Current State

Working locally at `http://localhost:38000`.

Flow2API and `flow_captcha_service` can be started together with `.\scripts\start-local-stack.ps1`. The unified stack uses Docker service discovery, so Flow2API reaches the captcha service at `http://flow-captcha-service:8060`.

Pic Batch can be added to the same stack with `docker-compose.pic-batch.yml`. It exposes Studio at `http://localhost:39000`, stores runtime data in `data/pic-batch/`, and should configure its Flow2API provider as `http://flow2api:8000`.

Flow2API is running with one configured token. `flow_captcha_service` is healthy in standalone mode and Flow2API reports `captcha_method: remote_browser`, `remote_browser_configured: true`.

Admin login uses the default local credentials `admin` / `admin`; this should be changed before any non-local exposure. The runtime API key is currently database-backed and may differ from `config/setting.toml` if changed through the admin UI.

## Verification Status

- Pic Batch override compose config passed with `docker compose -p gemini-flow-stack -f docker-compose.stack.yml -f docker-compose.pic-batch.yml config`.
- Pic Batch container build/health smoke is blocked by Docker/registry metadata retrieval for the base image `node:22-bookworm-slim`; retry after Docker Hub access/cache recovers.
- Docker local-source build: passed.
- Full mounted source tests in Docker dependency environment: `40 passed`. `pytest.ini` limits collection to Flow2API's own `tests/` so the ignored `third_party/flow_captcha_service` checkout is not collected.
- Flow2API health endpoint: passed, `backend_running: true`, `captcha_method: remote_browser`, `remote_browser_configured: true`.
- `flow_captcha_service` health endpoint: passed, `success: true`, `role: standalone`.
- Unified Docker stack: passed with `.\scripts\start-local-stack.ps1`; both services run in project `gemini-flow-stack`, and `flow-captcha-service` is healthy.
- Docker service-name connectivity: passed from `flow2api` to `http://flow-captcha-service:8060/api/v1/health`.
- Runtime captcha database config: passed, `captcha_method = remote_browser`, `remote_browser_base_url = http://flow-captcha-service:8060`, existing `remote_browser_api_key` preserved.
- Metrics endpoint: passed.
- Model list auth behavior: unauthenticated `401`; runtime database API key returns `200` with 169 models.
- Gemini-compatible image generation: passed on `/models/gemini-3.1-flash-image-landscape:generateContent`, returned one candidate with inline image data.
- Unified-stack image generation regression: passed, HTTP `200`, one response part with inline image data.
- Remote captcha handoff: passed; captcha service logs show `/api/v1/prefill`, `/api/v1/solve`, token acquisition, standby token refill, and `/finish`.
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
.\scripts\start-local-stack.ps1
docker compose -p gemini-flow-stack -f docker-compose.stack.yml ps
docker compose -p gemini-flow-stack -f docker-compose.stack.yml -f docker-compose.pic-batch.yml config
curl.exe -fsS http://127.0.0.1:38000/health
curl.exe -fsS http://127.0.0.1:8060/api/v1/health
curl.exe -fsS http://127.0.0.1:39000/api/health
```
