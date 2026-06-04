# Data Import and Sync

Tariff data is primarily imported from upstream CDS and TARIC update files. UK mode uses CDS; XI mode uses TARIC.

## Shared Synchronizer Behaviour

`app/lib/tariff_synchronizer.rb` contains shared update behaviour:

- Acquire a Redis lock before download, apply, or rollback work.
- Check failed updates before applying new updates.
- Check update filename sequencing.
- Apply pending updates from the oldest pending issue date to the requested date.
- Run `TariffSynchronizer::BaseUpdateImporter` for each pending update.
- Roll back oplog-backed records after a selected date.
- Emit instrumentation and notify Slack on failure paths.

Successful sync paths usually have follow-on work: cache invalidation, search/cache index rebuilding, reports, and generated classification content refresh. Check worker code and `config/sidekiq.yml` before changing sync behaviour, because UK and XI schedules differ.

## Sync Configuration

The sync pipeline reads these environment variables, with defaults preserved when unset:

- `TARIFF_SYNC_RETRY_COUNT`: download retry budget, default `20`.
- `EXCEPTION_RETRY_COUNT`: retry budget for exceptional download failures, default `10`.
- `REQUEST_THROTTLE`: seconds before retrying retriable downloads, default `60`.
- `CUT_OFF_TIME`: latest time to keep waiting for today's CDS file, default `10:00`.
- `TRY_AGAIN_IN`: minutes before retrying when today's CDS file has not arrived, default `20`.
- `EMPTY_FILE_SIZE_THRESHOLD`: bytes below which an empty CDS update is treated as expected, default `500`.

## CDS and TARIC Modes

`app/lib/cds_synchronizer.rb` extends `TariffSynchronizer` for UK CDS updates. It requires `HMRC_API_HOST`, `HMRC_CLIENT_ID`, and `HMRC_CLIENT_SECRET` before download.

`app/lib/taric_synchronizer.rb` extends `TariffSynchronizer` for XI TARIC updates. It requires `TARIFF_SYNC_USERNAME`, `TARIFF_SYNC_PASSWORD`, and `TARIFF_SYNC_HOST` before download.

## Operational Tasks

The main Rake entry points are in `lib/tasks/tariff.rake`:

- `tariff:sync` queues download, apply, and reindex work.
- `tariff:sync:download` downloads pending upstream update files.
- `tariff:sync:apply` applies pending updates.
- `tariff:sync:rollback DATE=YYYY-MM-DD` rolls back update data.
- `tariff:reindex` rebuilds relevant OpenSearch entities.
- `tariff:check_integrity` checks goods nomenclature tree integrity.

## Data Migrations

Application-level data migrations live under `db/data_migrations/`. These are separate from schema migrations under `db/migrate/` and are used for targeted production data repairs or backfills.

## External Feeds and Integrations

High-level Confluence context describes CDS/TARIC import as the nightly source of tariff truth. In this repo, verify implementation through:

- `app/lib/cds_synchronizer.rb`
- `app/lib/taric_synchronizer.rb`
- `app/lib/tariff_synchronizer/`
- `app/workers/cds_updates_synchronizer_worker.rb`
- `app/workers/taric_updates_synchronizer_worker.rb`
- `lib/tasks/tariff.rake`

## Related Docs

- [Goods Nomenclature Nested Set](../goods-nomenclature-nested-set.md)
- [Generated classification content lifecycle](../generated-classification-content-lifecycle.md)
- [Reporting](../reporting.md)
