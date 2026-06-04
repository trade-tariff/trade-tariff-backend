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

## PR Risk Labels

When opening a PR, use `.github/pull_request_template.md` as the canonical risk decision tree. Fill in the Risk section and apply exactly one matching GitHub label:

- `low-risk` for green changes: standard review. Typical examples include dependency bumps with no API changes, copy/content changes, read-only observability, tests-only changes, additive config with safe defaults, covered refactors with no behaviour change, Terraform changes with no resource recreation, and non-destructive S3 lifecycle rules.
- `medium-risk` for amber changes: socialise with the team before merging. Typical examples include commodity code lookup, measure type, declarable goods, quota, or duty calculation changes; OpenSearch indexing changes; new or modified consumed API endpoints; feature flags affecting live journeys; networking, security group, IAM, CI/CD, deployment ordering, S3 access-control, resource replacement, or deprecation changes.
- `high-risk` for red changes: requires explicit approval from Thor or Neil before merging. Typical examples include destructive database migrations, changes to how measures, conditions, or footnotes are processed or surfaced, CDS or HMRC upstream sync changes, production AWS changes that cannot be easily rolled back, secrets or credential handling changes, legally significant trader-facing regulatory content changes, and significant architectural shifts.

Do not apply more than one risk label to the same PR. If the risk rating changes during review, remove the old risk label and apply the new one.

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
