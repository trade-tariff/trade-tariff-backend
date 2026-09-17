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
The storage and rebuild layer does not itself schedule work or change API reads.
