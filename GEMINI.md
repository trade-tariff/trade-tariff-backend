# Gemini Instructions

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

Before opening a PR:

- Use `.github/pull_request_template.md` as the canonical risk decision tree.
- Fill in the Risk section and apply exactly one matching GitHub label: `low-risk` for green, `medium-risk` for amber, or `high-risk` for red.
- Treat dependency bumps with no API changes, copy/content changes, read-only observability, tests-only changes, additive config with safe defaults, covered refactors with no behaviour change, Terraform changes with no resource recreation, and non-destructive S3 lifecycle rules as typical `low-risk` changes.
- Treat commodity code lookup, measure type, declarable goods, quota, duty calculation, OpenSearch indexing, consumed API endpoint, live feature flag, networking, security group, IAM, CI/CD, deployment ordering, S3 access-control, resource replacement, and deprecation changes as typical `medium-risk` changes that need a team conversation before merging.
- Treat destructive database migrations, measure/condition/footnote processing, CDS or HMRC upstream sync, hard-to-rollback production AWS, secrets or credential handling, legally significant regulatory content, and significant architecture changes as typical `high-risk` changes that require explicit approval from Thor or Neil.
- If the risk rating changes during review, remove the old risk label and apply the new one.

Useful docs:

- `docs/development-and-delivery.md`
- `docs/confluence.md`
- `docs/code-wiki.md`
- `docs/architecture/request-routing.md`
- `docs/architecture/data-import-and-sync.md`
- `docs/architecture/search-and-indexing.md`
- `docs/architecture/caching-and-background-jobs.md`
- `docs/architecture/api-documentation.md`
