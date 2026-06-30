# Flow2API Local Acceptance Test Plan

## Preconditions

- Docker Desktop is running.
- `config/setting.toml` exists. If missing, copy it from `config/setting_example.toml`.
- `flow_captcha_service` is deployed under `third_party/flow_captcha_service` and started in `standalone` mode.
- Local source deployment is started with:

```powershell
docker compose -f docker-compose.local.yml up -d --build
```

- Captcha mode is set to `remote_browser` in the running Flow2API configuration.
- `remote_browser_base_url` points to `http://host.docker.internal:8060` from the Flow2API container.
- `remote_browser_api_key` matches a service API key created in `flow_captcha_service`.
- A valid Flow/ST token has been added through the Flow2API Token Updater extension or admin UI.

Runtime note: Flow2API loads admin/API settings from `data/flow.db` after startup. If the admin UI changed the API key, the database value overrides `config/setting.toml`.

## Baseline Checks

1. Flow2API container is running:

```powershell
docker compose -f docker-compose.local.yml ps
```

Expected: `flow2api` is `Up` and publishes `38000->8000`.

2. Captcha service container is running:

```powershell
docker ps --filter "name=flow-captcha-service"
```

Expected: `flow-captcha-service` is `Up` and publishes `8060->8060`.

3. Startup logs are clean:

```powershell
docker compose -f docker-compose.local.yml logs --tail=120 flow2api
docker logs --tail 120 flow-captcha-service
```

Expected:

- Flow2API startup complete, database initialized or migrated, server running on `0.0.0.0:8000`.
- Flow2API logs include `Remote browser pool prefill started` when a token/project is available.
- Captcha service health checks return `200`.
- Captcha service logs show browser token acquisition or standby token refill when prefill/generation is exercised.

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
| Flow2API health | `GET /health` | `200`, `backend_running: true`, `captcha_method: remote_browser`, `remote_browser_configured: true` |
| Captcha service health | `GET http://localhost:8060/api/v1/health` | `200`, `success: true`, `role: standalone` |
| Login page/admin entry | `GET /` | `200`, HTML returned |
| Metrics | `GET /metrics` | `200`, Prometheus text returned |
| API auth required | `GET /v1/models` | `401` without bearer token |
| API key accepted | `GET /v1/models` with the runtime API key | `200`, model list returned |
| Admin login | `POST /api/login` with `admin` / `admin` | `200`, `success: true` |
| Admin stats after login | `GET /api/stats` with admin cookie | `200`, stats JSON returned |

### Getting the Runtime API Key for Local Testing

If `han1234` returns `401`, read the current database-backed API key locally:

```powershell
$apiKey = docker exec flow2api sh -lc "python - <<'PY'
import sqlite3
con = sqlite3.connect('/app/data/flow.db')
cur = con.cursor()
cur.execute('select api_key from admin_config where id=1')
print(cur.fetchone()[0])
con.close()
PY"
```

Use this value as `Authorization: Bearer $apiKey` or `x-goog-api-key: $apiKey`.

## Remote Browser Captcha Acceptance

1. Confirm Flow2API sees the remote browser service:

```powershell
curl.exe -fsS http://127.0.0.1:38000/health
```

Expected: `captcha_method` is `remote_browser` and `remote_browser_configured` is `true`.

2. Confirm `flow_captcha_service` is reachable:

```powershell
curl.exe -fsS http://127.0.0.1:8060/api/v1/health
```

Expected: `success: true`.

3. Exercise the remote captcha path through either prefill logs or a generation request.

Expected: `flow-captcha-service` logs show `token acquired` or `standby token refilled`; Flow2API logs do not show remote captcha auth or connection errors.

## Image Generation Acceptance

Run a Gemini-compatible image request with the runtime API key:

```powershell
$apiKey = "<runtime API key>"
$body = @{
  contents = @(
    @{
      role = "user"
      parts = @(
        @{ text = "A small red teapot on a white table, product photo, soft daylight" }
      )
    }
  )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:38000/models/gemini-3.1-flash-image-landscape:generateContent" `
  -Headers @{ "x-goog-api-key" = $apiKey } `
  -ContentType "application/json" `
  -Body $body `
  -TimeoutSec 240
```

Expected:

- HTTP `200`.
- Response contains `candidates[0].content.parts`.
- At least one part contains `inlineData.data` or a usable generated media URL.
- Flow2API releases pending/concurrency state after the request.
- If upstream Flow/Labs rejects the account, returns quota errors, or token becomes invalid, record the exact upstream error and treat the issue as credential/account-dependent rather than local deployment failure.

## Manual UI Checks

1. Open `http://localhost:38000`.
2. Log in with `admin` / `admin`.
3. Confirm the manage dashboard loads.
4. Confirm captcha settings show `remote_browser`.
5. Confirm token count is at least `1` when the extension has submitted a token.
6. Open `http://localhost:38000/test`; without admin session it may redirect to login, with a session it should load the model test page.
7. Submit a small image prompt from the test page and confirm the page shows either a generated image or a clear upstream credential/account error.

Playwright is useful for this section when a browser-level acceptance record is needed:

- Open `/`.
- Log in.
- Visit `/manage` and `/test`.
- Submit a short prompt.
- Capture screenshots of the dashboard and result/error state.

## Deferred Credential-Required Tests

These are intentionally postponed until the relevant accounts/API keys are available:

- Convert ST to AT if only ST is available.
- Refresh AT and token balance if the current token does not support it.
- Generate and poll a video task.
- Validate proxy mode if a proxy account is provided.
- Validate third-party captcha providers such as YesCaptcha, CapMonster, EzCaptcha, or CapSolver.

## Acceptance Criteria

Local remote-browser acceptance is complete when:

- `flow_captcha_service` health passes.
- Flow2API health passes and reports `remote_browser`.
- Flow2API authenticated model listing passes with the runtime API key.
- Remote captcha handoff is observed in logs or during generation.
- At least one real image generation request succeeds, or failure is proven to be an upstream account/credential/quota issue rather than a local deployment/configuration issue.

Full product acceptance additionally requires all deferred credential/account-dependent tests to pass after credentials are available.
