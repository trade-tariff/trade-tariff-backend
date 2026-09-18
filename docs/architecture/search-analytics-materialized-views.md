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
refresh; subsequent refreshes can run concurrently with readers.

## Consistency and refresh

The helper obtains a schema-specific advisory lock, then starts a repeatable-read
transaction. It refreshes dependencies first and source revision metadata last,
publishing all four materialized views together. A failure rolls back the entire
refresh. Unchanged sources require no rebuild. A forced refresh is available for
repair; it does not recollect CloudWatch data.

This change does not pin API reads to the views or add a faster API path.
Missing, incompatible or unpopulated materialized data has no effect on the
existing reader. No web request refreshes a view or collects logs.

Refresh settings are transaction-local: UTC, 64 MB `work_mem`, 4 GB temporary-file
limit and 120 seconds per statement. The file limit applies to simultaneous
backend temporary files, not cumulative writes over all refresh statements.
Read-side aggregation uses 32 MB `work_mem`. These are per-operation allowances,
not whole-process caps. Neither setting changes pooled connection defaults.

A native materialized-view refresh recomputes the whole relation, not only the
changed reporting day. Keep this cost in operational capacity planning; the
benefit is lower read latency and web-process memory, not free refresh work.
