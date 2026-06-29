# Technical Decisions

## 2026-06-29: Prefer Docker Local-Source Deployment

Decision: use `docker-compose.local.yml` for the final local deployment instead of the default `docker-compose.yml`.

Rationale: the default compose file pulls `ghcr.io/thesmallhancat/flow2api:latest`, while local verification and fixes were made against this checkout. `docker-compose.local.yml` builds `flow2api:local` from the current source and keeps runtime behavior aligned with tested code.

Impact: local service remains available at `http://localhost:38000`, with `data/`, `tmp/`, and `config/setting.toml` mounted from the workspace.
