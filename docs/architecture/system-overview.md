# System Overview

Trade Tariff Backend is the central data and API layer for the Trade Tariff service. It serves commodity classification, duty and tariff information, search, exchange rate, Green Lanes, news, rules of origin, user subscription, and admin data for imports and exports under the UK Global Tariff and Windsor Framework.

There is no user-facing HTML in this application. It is an API-only Rails application; user interfaces live in separate services such as Trade Tariff Frontend and Trade Tariff Admin.

## Runtime Shape

The core stack is:

- Ruby and Rails for the application framework.
- Sequel and PostgreSQL for tariff data models and queries.
- Redis for Sidekiq and application locking.
- Sidekiq and sidekiq-scheduler for background jobs.
- OpenSearch for search and cache indexes.
- AWS SDK clients for persistence, reporting, mail, and related integrations.

The dependency list is in `Gemfile`.

## Service Mode

The application runs in either UK or XI mode. `TradeTariffBackend.service`, `uk?`, and `xi?` read `SERVICE` from the environment in `app/lib/trade_tariff_backend/config.rb`.

Service mode affects:

- Which Rails engines are mounted in `config/routes.rb`.
- Which update synchronizer runs.
- Which scheduled jobs are enabled in `config/sidekiq.yml`.
- Which currency and upstream data source are used.
- Which feature areas are available. Exchange rates and Rules of Origin are UK-only; Green Lanes categorisation is XI-focused.

## API Surfaces

The backend exposes distinct API surfaces:

- Public V2 API for current Trade Tariff integrations.
- Legacy V1 API for older consumers.
- Admin API for internal admin tooling.
- User API for MyOTT subscriptions and user-specific tariff changes.
- Internal API for platform-to-platform integration.

Keep these surfaces separate when assessing compatibility and tests. A public V2 change usually needs OpenAPI coverage; an admin or internal change may not.

## Major Boundaries

- Public API routing lives in mounted engines under `app/engines/`.
- Public V2 controllers live under `app/controllers/api/v2/`.
- Admin controllers live under `app/controllers/api/admin/`.
- Domain models live under `app/models/` and are mostly Sequel-backed.
- Import and sync code lives under `app/lib/` and `lib/tasks/`.
- Search services and index definitions live under `app/services/search_service/`, `app/queries/search/`, and `app/indexes/search/`.
- Background workers live under `app/workers/`.
- JSON API serializers and presenters live under `app/serializers/` and `app/presenters/`.

## Reading Path

For a new feature, start with the route, then follow the controller to the service/query/presenter/serializer layer. For tariff data changes, start with the relevant model and check whether the record is imported from CDS/TARIC, derived by a worker, or manually managed by admin APIs.

## Wider Platform

The broader OTT platform runs in AWS and includes Frontend, Admin, Identity, Developer Hub, Commodi-Tea, and other services. For the business and platform context behind this backend, see [Platform context](platform-context.md) and [Confluence references](../confluence.md).
