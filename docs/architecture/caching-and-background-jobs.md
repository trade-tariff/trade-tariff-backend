# Caching and Background Jobs

The application uses Rails cache, Redis, Sidekiq, and OpenSearch cache indexes to keep expensive tariff responses and background work manageable.

## Rails Cache

The detailed cache behaviour is documented in [Caching within the Trade Tariff apps](../caching.md).

`app/services/cached_commodity_service.rb` is a key example. It builds a cache key from commodity SID, actual date, cache version, and the current Meursing additional code. Today's commodity responses are cached longer than historical responses, and geography-specific filtering is applied after fetching cached data.

Other important cache and rate-limit entrypoints:

- `app/controllers/concerns/etag_caching.rb` sets HTTP caching semantics for API responses.
- `app/middleware/clear_cache_control.rb` prevents unintended cache headers for non-frontend callers.
- `app/workers/clear_cache_worker.rb` coordinates backend/frontend cache clearing after data changes.
- `app/workers/invalidate_cache_worker.rb` handles CDN invalidation.
- `config/initializers/rack_attack.rb` uses Redis for rate-limiting state; this is not content caching.

When changing cached responses:

- Check the cache key and cache version.
- Check whether filters are applied before or after the cache fetch.
- Check cache invalidation workers and admin cache clear paths.
- Check whether the state is content cache, index data, CDN cache, or rate-limit state.
- Add request/service specs around observable response changes.

## Redis Locks

Sync and rollback work use `TradeTariffBackend.with_redis_lock` so only one update process mutates tariff data at a time. The synchronizer code emits instrumentation when locks are acquired or fail.

## Sidekiq

Workers live under `app/workers/`. Queues and scheduled jobs are configured in `config/sidekiq.yml`.

Queues:

- `sync`
- `default`
- `within_1_hour`
- `within_1_day`

Scheduled jobs include CDS/TARIC sync, goods nomenclature reconciliation, Appendix 5A refresh, search suggestions, reports, integrity checks, exchange rates, sync age metrics, FAQ feedback reports, subscriber cleanup, and GOV.UK Customs Tariff document imports.

## Operational Tasks

Common task files:

- `lib/tasks/tariff.rake` for sync, rollback, reindex, tree integrity, and tariff changes.
- `lib/tasks/opensearch.rake` for OpenSearch index rebuilds.
- `lib/tasks/reporting.rake` for report generation.
- `lib/tasks/labels.rake` and `lib/tasks/self_texts.rake` for generated classification content.
