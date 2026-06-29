# Project Status

## Current Focus

Local deployment and acceptance verification of `TheSmallHanCat/flow2api`.

## Latest Meaningful Changes

- Created local runtime config from `config/setting_example.toml`.
- Deployed the service with `docker-compose.local.yml` using a local-source image.
- Fixed two source-test regressions in `src/services/flow_client.py`:
  - API captcha token retrieval now tolerates test/lightweight instances that bypass `__init__`.
  - Video status normalization preserves `fifeUrl` in operation metadata.
- Added project memory and verification notes.

## Current State

Working locally at `http://localhost:38000`.

Admin login uses the default local credentials `admin` / `admin`; this should be changed before any non-local exposure. No Flow tokens or third-party captcha credentials are configured, so real image/video generation is not yet accepted.

## Verification Status

- Docker local-source build: passed.
- Full mounted source tests in Docker dependency environment: `40 passed`.
- Health endpoint: passed, `backend_running: true`.
- Metrics endpoint: passed.
- Model list auth behavior: unauthenticated `401`, bearer `han1234` returns models.
- Admin login and stats API: passed.

## Deferred Acceptance

Pending valid credentials:

- Add and validate a real Flow/ST token.
- ST to AT conversion and AT refresh.
- Image generation through OpenAI-compatible and Gemini-compatible routes.
- Video generation and polling through OpenAI-compatible and Gemini-compatible routes.
- Token balance refresh.
- YesCaptcha/CapMonster/EzCaptcha/CapSolver or browser/personal captcha solving.

## Useful Commands

```powershell
docker compose -f docker-compose.local.yml ps
docker compose -f docker-compose.local.yml logs -f flow2api
docker compose -f docker-compose.local.yml down
docker compose -f docker-compose.local.yml up -d --build
```
