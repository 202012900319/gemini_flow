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

Smoke check the running service with `/health`, `/metrics`, `/v1/models`, and `/api/login`.
