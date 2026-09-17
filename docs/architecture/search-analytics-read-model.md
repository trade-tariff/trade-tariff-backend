# Search analytics read model

Daily query results remain the source of truth. The read model derives compact
journey statistics from them without changing collection or querying CloudWatch.
It avoids transferring every stored journey identifier to the web process.

## Representation

Each generation contains:

- Daily observations keyed by a binary SHA-256 journey identifier. Hour masks
  record starts for All, Classic and Internal. Terminal time/state and action
  flags retain the information required for range reconciliation.
- Daily and hourly rollups for identities observed on only one reporting date.
- Separate observations for identities present on multiple dates. These must be
  reconciled within the requested range, rather than adding daily unique counts.
- Source revisions, query fingerprints, service, region and a processing version.

A rebuild recalculates which identities span dates. This handles both promotion
and demotion when source results are replaced or removed. It preserves latest
terminal state, conflicting states, and overlapping selected/zero-result flags.

## Explicit rebuild

Migrate the selected service before building a generation. From its backend
application environment, run:

```sh
bundle exec rake search_analytics:rebuild_read_model
```

The default window covers the last 366 completed UTC dates. Only stored results
with current query fingerprints contribute. A narrower initial window is possible:

```sh
FROM=2026-09-01 TO=2026-09-16 bundle exec rake search_analytics:rebuild_read_model
```

An explicit changed rebuild must include all dates already covered by that
service's generation. Use the default rebuild to advance the rolling window.
A no-op can reuse an existing generation covering a larger requested window.

The operator's database role must be allowed to set `temp_file_limit`. The build
uses transaction-local UTC, 64 MB `work_mem`, a 4 GB temporary-file limit, and a
120-second timeout per SQL statement. `work_mem` is a per-operation setting, not
a total process-memory cap. These settings do not change the pool's defaults.

The rebuild owns its repeatable-read transaction and takes a nonblocking
service-specific advisory lock. Normalisation and rollups run one date at a time;
Ruby only loads source metadata. If another rebuild holds the lock, wait for it
to finish before retrying the task.

The new generation and its source revisions become visible together. Older
generations for the same service and region are removed in the same transaction.
Failure rolls back the new generation and leaves the previous one available.
The original query-result rows are never changed by a rebuild.

This task is database preparation, not a historical CloudWatch backfill. Rebuild
after restoring or changing source results before relying on the derived data.
Building the first generation opts that service and region into scheduled
maintenance. The maintenance worker checks every fifteen minutes and does no
bulk work before this explicit bootstrap.

## API reads

`DailyResults` first checks metadata, without loading the identifier or term
blobs. It uses a generation only when its processing version, query fingerprints
and source revisions match every complete selected day. Source data and the
chosen generation are read in one read-only, repeatable-read transaction. MVCC
keeps that generation visible if another connection replaces it during the request.

The API reconciles multi-day identities in PostgreSQL and returns compact counts.
It also aggregates and ranks term totals in PostgreSQL before applying the
per-type limit. The serializer, metric definitions and coverage rules stay the same.

A compatible generation is required for the lower-memory path. An absent or
outdated generation uses the existing reader, including its higher latency and
memory cost. Calls inside an existing caller transaction also use that reader,
because the fast path cannot establish its own snapshot isolation there.
After source changes, the next successful maintenance run restores the fast path.
Run an explicit rebuild to avoid waiting for the next scheduled check.

Fast reads use transaction-local 32 MB `work_mem`. This permits range aggregation
without changing the shared pool's session defaults. No result cache is added to
web or worker processes.

## Scheduled maintenance

`SearchAnalyticsReadModelWorker` uses `within_1_day` with automatic retries
disabled. It skips services without a generation. The rebuild service skips
unchanged source revisions before applying its SQL resource settings. If another
rebuild holds the advisory lock, the worker waits until its next scheduled check;
other failures remain visible through normal job reporting.

Maintenance uses the same database role and bounds as the explicit task. Confirm
that role can set `temp_file_limit` and review shared database capacity before
bootstrapping in production. A changed generation can require a full rebuild of
available data in the rolling 366-day window. It does not run CloudWatch queries
or hold identifier collections in worker memory.
