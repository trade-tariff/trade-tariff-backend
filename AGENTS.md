# Agent Instructions

Use these instructions for Codex and other agentic coding tools working in this repository.

## Start Here

Read these first:

- `docs/README.md`
- `docs/architecture/README.md`
- `docs/development-and-delivery.md`
- `docs/code-wiki.md`
- `README.md`

The application is a Rails API using Sequel, PostgreSQL, Redis, Sidekiq, and OpenSearch. It runs in UK or XI service mode via `SERVICE`.

## Working Rules

- Keep scope tight and prefer simple changes.
- Verify generated or AI-suggested claims against source code and tests.
- Write controller coverage as request specs under `spec/requests/`. Do not add new files under `spec/controllers/`; when touching legacy controller specs, migrate the coverage into request specs and remove the controller spec.
- Request specs must use concrete paths or route helpers, not controller-style action symbols such as `get :show`.
- Use Ruby data classes such as `Data.define` for simple value objects. Do not introduce `Struct`.
- For public V2 API changes, update swagger specs under `spec/swagger/api/v2/`.
- Do not manually edit generated `swagger/v2/swagger.json` for endpoint changes.
- Run project commands directly by default. If you use Nix/direnv locally, `direnv exec <repo-path> <command>` is also fine.
- Use `rg` for code search.
- Treat tariff data, measures, quotas, duties, certificates, rules of origin, auth, and sync logic as high-risk areas.

## Key Entry Points

- Routes: `config/routes.rb` and `app/engines/`
- Public V2 controllers: `app/controllers/api/v2/`
- Admin controllers: `app/controllers/api/admin/`
- Models: `app/models/`
- Services: `app/services/`
- Import and sync: `app/lib/`, `lib/tasks/tariff.rake`
- Search: `app/services/search_service.rb`, `app/indexes/search/`, `app/queries/search/`
- Workers: `app/workers/`, `config/sidekiq.yml`
- API docs: `spec/swagger/api/v2/`, `lib/tasks/swagger.rake`
- Wider platform context: `docs/confluence.md`
