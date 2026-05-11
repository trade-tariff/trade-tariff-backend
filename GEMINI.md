# Gemini Instructions

Use `docs/README.md` as the first repository map and `docs/architecture/README.md` for system boundaries.

This is a Rails API backed by Sequel/PostgreSQL, Redis, Sidekiq, and OpenSearch. Service-specific behaviour is controlled by `SERVICE=uk` or `SERVICE=xi`.

Before changing code:

- Identify the route, controller, service/query/model, serializer, and tests involved.
- Verify generated explanations against source files.
- Read the relevant architecture or domain doc before editing tariff data, search, sync, caching, Green Lanes, rules of origin, exchange rates, or API documentation.
- Run project commands directly by default. If you use Nix/direnv locally, `direnv exec <repo-path> <command>` is also fine.

Useful docs:

- `docs/development-and-delivery.md`
- `docs/confluence.md`
- `docs/code-wiki.md`
- `docs/architecture/request-routing.md`
- `docs/architecture/data-import-and-sync.md`
- `docs/architecture/search-and-indexing.md`
- `docs/architecture/caching-and-background-jobs.md`
- `docs/architecture/api-documentation.md`
