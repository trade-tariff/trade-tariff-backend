# Search analytics SQL views

`search_analytics_query_results` remains the source of truth: one latest successful
result per service, reporting date and query name. Refreshing a result replaces
that slot. This is not an operation log, and these models do not use the oplog
plugin.

The read side follows the existing tariff-data idiom: SQL views express the
transformation, indexed materialized views retain expensive results, and refresh
is separate from page reads.

## Relations

- `search_analytics_journey_observation_rows` expands the two identifier-bearing
  query groups into typed SQL observations.
- `search_analytics_daily_journeys` materializes one row per service, date and
  journey, with hourly presence, latest terminal state and action flags.
- `search_analytics_repeated_journey_keys` identifies journeys spanning dates.
- `search_analytics_repeated_journeys` materializes those observations so range
  reconciliation does not scan every journey.
- `search_analytics_journey_rollup_rows` composes daily/hourly statistics for
  journeys confined to one date.
- `search_analytics_journey_rollup_totals` materializes those statistics.
- `search_analytics_source_revisions` materializes source identity, fingerprints
  and collection timestamps. It is current-state metadata, not a change history.

The relations store compact daily and hourly journey statistics plus the
repeated-identity observations needed for later range reconciliation. They do
not store term rankings or identifier collections. This change does not alter
API reads.

## Migration and initial population

Versioned Sequel migrations create the views, materialized views, supporting
aggregate and indexes in the current UK/XI schema. Materialized views are created
without data to keep population out of the schema migration.

After deploying the migration, populate the selected service explicitly:

```sh
bundle exec rake search_analytics:refresh_views
```

Use the service environment containing the stored query results. The database
role must own the materialized views and be permitted to set `temp_file_limit`.
No permissions are changed by this feature. Initial population uses a blocking
refresh; subsequent refreshes can run concurrently with readers. Completing this
bootstrap also enables completion-triggered maintenance for this service.

## Collection completion

After bootstrap, successful `search_journeys` and `journey_outcomes` jobs enqueue
`SearchAnalyticsRefreshViewsWorker`. Unrelated optional-query failures must not
leave these updated inputs stale indefinitely. Completed daily collection and
already-current backfill requests can also enqueue a refresh. These signals do
not submit more CloudWatch queries.

The refresh worker uses `within_1_day`, without automatic retries. It does not
wait for the refresh lock. If a refresh or bootstrap already holds the lock, one
delayed followup is scheduled and further busy signals share that followup. The
followup rechecks freshness after the lock is free, so a source update committed
during an active refresh is not lost. Duplicate signals normally become no-ops.
SQL failures do not schedule a followup.

There is no fifteen-minute polling schedule. View population remains explicit:
the worker asks the helper to skip unpopulated views after taking the lock, so it
does not bootstrap a service that has not adopted the views. If enqueueing or
refreshing fails, stored query results remain intact. Use `search_analytics:refresh_views` after resolving
the failure. The rake command finishing its enqueue is not proof that collection
or refresh finished.

## Consistency and refresh

The helper obtains a schema-specific advisory lock, then starts a repeatable-read
transaction. It refreshes dependencies first and source revision metadata last,
publishing all four materialized views together. A failure rolls back the entire
refresh. Unchanged sources require no rebuild. A forced refresh is available for
repair; it does not recollect CloudWatch data. A caller may skip unpopulated
views after the lock is taken. A non-waiting caller still receives a lock error
while another refresh holds it.

This change does not pin API reads to the views or add a faster API path.
Missing, incompatible or unpopulated materialized data has no effect on the
existing reader. No web request refreshes a view or collects logs.

Refresh settings are transaction-local: UTC, 64 MB `work_mem`, 4 GB temporary-file
limit and 120 seconds per statement. The file limit applies to simultaneous
backend temporary files, not cumulative writes over all refresh statements.
These are per-operation allowances, not whole-process caps. They do not change
pooled connection defaults.

A native materialized-view refresh recomputes the whole relation, not only the
changed reporting day. Keep this cost in operational capacity planning; the
benefit is lower read latency and web-process memory, not free refresh work.
