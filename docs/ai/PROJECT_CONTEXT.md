# Flow2API Project Context

## Purpose

Flow2API is a FastAPI service that exposes OpenAI-compatible and Gemini-compatible endpoints backed by Google Flow/Labs media generation workflows. It also includes a web admin UI for token, captcha, proxy, cache, and generation settings.

## Stack

- Python 3.11 in Docker, project advertises Python 3.8+
- FastAPI, Uvicorn
- SQLite via `aiosqlite`
- `curl-cffi`, `httpx`, `playwright`, `nodriver`
- Docker Compose for local deployment

## Key Paths

- `main.py`: root entry point
- `src/main.py`: FastAPI app, lifespan startup, static page routing
- `src/api/routes.py`: OpenAI/Gemini-compatible API routes
- `src/api/admin.py`: admin and management routes
- `src/services/flow_client.py`: upstream Flow/Labs client and generation/status logic
- `config/setting_example.toml`: default configuration template
- `config/setting.toml`: local ignored runtime configuration
- `data/`: ignored SQLite runtime data
- `tmp/`: ignored generated/cache runtime files
- `tests/`: source-level unit tests

## Local Deployment

Preferred one-command local stack for Flow2API plus headed remote captcha service:

```powershell
.\scripts\start-local-stack.ps1
```

This uses `docker-compose.stack.yml` with Compose project `gemini-flow-stack`, starts `flow2api` and `flow-captcha-service` on the same default Docker network, and sets Flow2API's remote browser URL to `http://flow-captcha-service:8060`. The launcher preserves the existing `remote_browser_api_key` in `data/flow.db`.

Optional Pic Batch Studio deployment uses an override file:

```powershell
docker compose -p gemini-flow-stack -f docker-compose.stack.yml -f docker-compose.pic-batch.yml up -d --build
```

This adds a separate `pic-batch` service at `http://localhost:39000`, with persistent runtime data under `data/pic-batch/`. The Pic Batch provider Base URL must use Docker service discovery: `http://flow2api:8000`.

Keep `config/setting.toml` encoded as UTF-8. The launcher reads and writes it explicitly as UTF-8 because Python `tomli` fails startup on non-UTF-8 TOML files.

Use the local-source compose file so the running container matches the checkout:

```powershell
if (!(Test-Path config\setting.toml)) { Copy-Item config\setting_example.toml config\setting.toml }
docker compose -f docker-compose.local.yml up -d --build
```

Service URL: `http://localhost:38000`.

Default local credentials from the example config are `admin` / `admin` for admin login and `han1234` for API bearer auth. Change them before exposing the service beyond local testing.

## Verification Commands

Build a dependency-compatible verification image:

```powershell
docker build -t flow2api-local-verify .
```

Run source tests with the current checkout mounted into that image:

```powershell
docker run --rm -v "${PWD}:/workspace" -w /workspace flow2api-local-verify sh -lc "python -m pip install pytest -q && python -m pytest -q"
```

`pytest.ini` intentionally limits collection to `tests/`; `third_party/flow_captcha_service` is an ignored external checkout and should not be collected as part of Flow2API tests.

Smoke check the running service with `/health`, `/metrics`, `/v1/models`, and `/api/login`.

For unified stack checks:

```powershell
docker compose -p gemini-flow-stack -f docker-compose.stack.yml ps
docker compose -p gemini-flow-stack -f docker-compose.stack.yml -f docker-compose.pic-batch.yml config
curl.exe -fsS http://127.0.0.1:8060/api/v1/health
curl.exe -fsS http://127.0.0.1:38000/health
curl.exe -fsS http://127.0.0.1:39000/api/health
docker exec flow2api python -c "import urllib.request; print(urllib.request.urlopen('http://flow-captcha-service:8060/api/v1/health', timeout=10).read().decode())"
```
