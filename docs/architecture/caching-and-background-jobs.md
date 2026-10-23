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

Each queue has a dedicated Sidekiq capsule. The default allocation per process is:

| Queue | Workload | Job threads |
| --- | --- | ---: |
| `sync` | Data sync jobs and their dependants | 1 |
| `within_1_minute` | Other data-related jobs, user-triggered jobs, and urgent notifications | 3 |
| `within_1_hour` | Report-related jobs | 2 |
| `within_1_day` | Most weekly and monthly jobs | 1 |
| `default` | Jobs without another queue assignment | 2 |
| `evaluation` | Evaluation searches | 1 |

`SIDEKIQ_CONCURRENCY` remains the total job-thread budget per process, defaulting to 10.
The named capsules reserve eight threads. The default capsule receives the remainder,
so the minimum total is nine. Process entrypoints continue to derive `DB_POOL` from
the total, unless explicitly overridden. Do not use the CLI `--concurrency` option
to set the total: it changes only the default capsule's allocation.

Capsules reserve job slots, not CPU, memory, or database capacity. Idle slots in one
capsule are not available to another capsule. The single `sync` thread serializes
that queue within one process only; Redis locks still protect updates across processes.
The scheduler can override a worker's queue with a `queue` setting in `config/sidekiq.yml`.
Otherwise, the worker's `sidekiq_options` queue applies. Jobs without either setting use
`default`. Queue names do not enforce completion deadlines. Jobs in each queue share that
queue's capsule capacity.

Scheduled jobs include CDS/TARIC sync, goods nomenclature reconciliation, Appendix 5A refresh, search suggestions, reports, integrity checks, exchange rates, sync age metrics, FAQ feedback reports, subscriber cleanup, and GOV.UK Customs Tariff document imports.

## Operational Tasks

Common task files:

- `lib/tasks/tariff.rake` for sync, rollback, reindex, tree integrity, and tariff changes.
- `lib/tasks/opensearch.rake` for OpenSearch index rebuilds.
- `lib/tasks/reporting.rake` for report generation.
- `lib/tasks/labels.rake` and `lib/tasks/self_texts.rake` for generated classification content.
