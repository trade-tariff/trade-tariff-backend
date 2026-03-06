# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Trade Tariff Backend is a Rails API that serves commodity code data for UK and XI (Northern Ireland) trade tariffs. It provides search, duty calculations, and tariff data to the Frontend, Admin, and Duty Calculator applications.

The app runs in one of two modes controlled by the `SERVICE` environment variable (`uk` or `xi`), which affects which routes, data, and logic are active.

## Commands

### Development

```sh
bin/setup           # Install dependencies and set up the database
bin/dev             # Start Rails + Sidekiq together
bin/rails s         # Start Rails server only
```

### Testing

```sh
bundle exec rspec                          # Run all tests
bundle exec rspec spec/models/chapter_spec.rb   # Run a single spec file
bundle exec rspec spec/models/chapter_spec.rb:42  # Run a specific line
```

### Linting

```sh
bin/rubocop                   # Run RuboCop
bin/rubocop -a                # Auto-fix offences
bin/brakeman                  # Security scan
```

### Database & Search

```sh
bin/rake db:migrate            # Run migrations
bin/rake tariff:reindex        # Rebuild OpenSearch indexes
bin/rake tariff:sync           # Trigger daily data sync via Sidekiq
```

## Architecture

### Dual-service design

The codebase serves both `uk` and `xi` services from a single Rails instance. All engines are mounted at both `/uk/...` and `/xi/...` URL prefixes simultaneously. The `SetRequestedService` middleware extracts the service from the request path and stores it in `TradeTariffRequest.service` (an `ActiveSupport::CurrentAttributes` attribute), making `TradeTariffBackend.service` / `.uk?` / `.xi?` return the correct value for the duration of each request. Background workers and non-HTTP contexts fall back to `ENV['SERVICE']` (default: `uk`).

UK-only endpoints (exchange rates, news) include the `UkOnly` concern which raises a routing error for XI requests. XI-only endpoints (green lanes) use the `XiOnly` concern similarly.

### API engines (`app/engines/`)

Routes are split into Grape-like Rails engines mounted in `config/routes.rb`:
- `V1Api` / `V2Api` — versioned public APIs, selected via `Accept` header (`application/vnd.uktt.v1` or `v2`)
- `AdminApi` — admin interface
- `InternalApi` — internal service-to-service routes
- `UserApi` — user-facing routes (UK only)

### Models use Sequel, not ActiveRecord

All models inherit from `Sequel::Model`. ActiveRecord is not used. Key Sequel plugins are configured globally in `config/application.rb`: `:time_machine`, `:oplog`, `:pagination`, `:pg_array`, `:pg_json`.

### TimeMachine

The `TimeMachine` plugin/concern is central to the app — it gates all database queries to return records valid at a specific date. Tests wrap examples in `TimeMachine.now { ... }` automatically (see `spec/rails_helper.rb`). Worker specs use `TimeMachine.no_time_machine { ... }`.

### GoodsNomenclature hierarchy (STI)

`GoodsNomenclature` uses STI to distinguish `Chapter`, `Heading`, `Subheading`, and `Commodity` based on the `goods_nomenclature_item_id` format and `producline_suffix`.

### Search

OpenSearch (configured via `ELASTICSEARCH_URL`) powers commodity search. Indexes are defined in `app/elastic_search_indexes/`. The `TradeTariffBackend.search_client` wraps index management; `bin/rake tariff:reindex` rebuilds all indexes.

### Background jobs

Sidekiq workers in `app/workers/` handle data sync, cache warming, report generation, and search reindexing. Daily sync workers are `CdsUpdatesSynchronizerWorker` (UK/CDS) and `TaricUpdatesSynchronizerWorker` (XI/TARIC).

### Services and serializers

Business logic lives in `app/services/`. API responses use `jsonapi-serializer` (JSON:API format) in `app/serializers/`, with legacy RABL templates in `app/views/`.

## Key conventions

- **Single quotes** for strings (enforced by RuboCop)
- **RuboCop govuk** preset (`rubocop-govuk`) — line length max 120
- Sidekiq jobs must use **scalar arguments only** (Integer, String, Boolean) — enforced by a custom cop (`Custom/SidekiqComplexArguments`)
- RSpec context blocks must be prefixed with `when`, `with`, `without`, or `for`
- Database uses **PostgreSQL with pgvector** extension; migrations use Sequel migration DSL
- Environment config is read via `TradeTariffBackend` module methods in `app/lib/trade_tariff_backend.rb`
