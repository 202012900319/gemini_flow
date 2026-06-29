# Flow2API Local Acceptance Test Plan

## Preconditions

- Docker Desktop is running.
- `config/setting.toml` exists. If missing, copy it from `config/setting_example.toml`.
- Local source deployment is started with:

```powershell
docker compose -f docker-compose.local.yml up -d --build
```

## Baseline Checks

1. Container is running:

```powershell
docker compose -f docker-compose.local.yml ps
```

Expected: `flow2api` is `Up` and publishes `38000->8000`.

2. Startup logs are clean:

```powershell
docker compose -f docker-compose.local.yml logs --tail=120 flow2api
```

Expected: application startup complete, database initialized or migrated, server running on `0.0.0.0:8000`.

## Automated Source Tests

Run tests inside the Docker dependency environment:

```powershell
docker build -t flow2api-local-verify .
docker run --rm -v "${PWD}:/workspace" -w /workspace flow2api-local-verify sh -lc "python -m pip install pytest -q && python -m pytest -q"
```

Expected: all tests pass.

Current result on 2026-06-29: `40 passed`.

## HTTP Smoke Tests

Use `http://localhost:38000`.

| Check | Request | Expected |
| --- | --- | --- |
| Health | `GET /health` | `200`, `backend_running: true` |
| Login page/admin entry | `GET /` | `200`, HTML returned |
| Metrics | `GET /metrics` | `200`, Prometheus text returned |
| API auth required | `GET /v1/models` | `401` without bearer token |
| API key accepted | `GET /v1/models` with `Authorization: Bearer han1234` | `200`, model list returned |
| Admin login | `POST /api/login` with `admin` / `admin` | `200`, `success: true` |
| Admin stats after login | `GET /api/stats` with admin cookie | `200`, stats JSON returned |

## Manual UI Checks

1. Open `http://localhost:38000`.
2. Log in with `admin` / `admin`.
3. Confirm the manage dashboard loads.
4. Confirm token count is `0` in this no-credential setup.
5. Open `http://localhost:38000/test`; without admin session it may redirect to login, with a session it should load the model test page.

## Deferred Credential-Required Tests

These are intentionally postponed until valid accounts/API keys are available:

- Add a real Flow session token and validate token health.
- Convert ST to AT.
- Refresh AT and token balance.
- Configure a real captcha method such as YesCaptcha, CapMonster, EzCaptcha, CapSolver, browser, personal, or remote browser.
- Generate an image through `/v1/chat/completions`.
- Generate an image through `/models/{model}:generateContent`.
- Generate and poll a video task.
- Validate proxy mode if a proxy account is provided.

## Acceptance Criteria

Local no-credential acceptance is complete when baseline checks, source tests, HTTP smoke tests, and admin login pass. Full product acceptance requires all deferred credential-required tests to pass after credentials are configured.
