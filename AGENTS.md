# Project Agent Notes

## Scope

This workspace is a local deployment and verification checkout of `TheSmallHanCat/flow2api`.

## Runtime

- Prefer Docker for local operation because the service dependencies are validated on Python 3.11 in the project Dockerfile.
- Standard local-source deployment:
  - `copy config\setting_example.toml config\setting.toml` if the local config is missing.
  - `docker compose -f docker-compose.local.yml up -d --build`
  - Service URL: `http://localhost:38000`
- Default local credentials from the example config:
  - Admin UI: `admin` / `admin`
  - API key: `han1234`
- `config/setting.toml`, `data/`, and `tmp/` are local runtime state and must not be committed.

## Verification

- Full source tests in the Docker dependency environment:
  - `docker run --rm -v "${PWD}:/workspace" -w /workspace flow2api-local-verify sh -lc "python -m pip install pytest -q && python -m pytest -q"`
- Basic service smoke checks:
  - `GET http://localhost:38000/health` returns `backend_running: true`
  - `GET http://localhost:38000/metrics` returns Prometheus metrics
  - `GET http://localhost:38000/v1/models` without auth returns `401`
  - `GET http://localhost:38000/v1/models` with `Authorization: Bearer han1234` returns model list
  - `POST http://localhost:38000/api/login` with default admin credentials returns success

## Account-Dependent Areas

Real image/video generation, Flow token validation, ST to AT conversion, token balance refresh, and third-party captcha solving require valid external accounts or service API keys. Keep these as pending acceptance checks until credentials are available.
