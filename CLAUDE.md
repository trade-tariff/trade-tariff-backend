# Claude Code Instructions

Use `docs/README.md` as the first repository map and `docs/architecture/README.md` for system boundaries.

This is a Rails API backed by Sequel/PostgreSQL, Redis, Sidekiq, and OpenSearch. Service-specific behaviour is controlled by `SERVICE=uk` or `SERVICE=xi`.

Before changing code:

- Identify the route, controller, service/query/model, serializer, and tests involved.
- Verify generated explanations against source files.
- Write controller coverage as request specs under `spec/requests/`. Do not add new files under `spec/controllers/`; when touching legacy controller specs, migrate the coverage into request specs and remove the controller spec.
- Request specs must use concrete paths or route helpers, not controller-style action symbols such as `get :show`.
- Treat swagger specs under `spec/swagger/api/v2/` as API documentation coverage, not a replacement for request specs.
- Use Ruby data classes such as `Data.define` for simple value objects. Do not introduce `Struct`.
- Read the relevant architecture or domain doc before editing tariff data, search, sync, caching, Green Lanes, rules of origin, exchange rates, or API documentation.
- Run project commands directly by default. If you use Nix/direnv locally, `direnv exec <repo-path> <command>` is also fine.
- Use `rg` for code search.

Useful docs:

- `docs/development-and-delivery.md`
- `docs/confluence.md`
- `docs/code-wiki.md`
- `docs/architecture/request-routing.md`
- `docs/architecture/data-import-and-sync.md`
- `docs/architecture/search-and-indexing.md`
- `docs/architecture/caching-and-background-jobs.md`
- `docs/architecture/api-documentation.md`
