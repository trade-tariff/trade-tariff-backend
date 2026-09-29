# Daily tariff updates

This guide is for maintainers who need to configure tariff imports. Basic local
setup and tests do not require access to the live upstream systems.

Updates run through `CdsUpdatesSynchronizerWorker` or
`TaricUpdatesSynchronizerWorker`, according to the service. Start with the
[data import and sync guide](architecture/data-import-and-sync.md) and check
[the Sidekiq schedule](../config/sidekiq.yml) before running a synchronizer.

The integrations use the following environment variables. Configure only the
integrations needed for the task, using approved credentials and destinations:

```text
AWS_ACCESS_KEY_ID
AWS_BUCKET_NAME
AWS_REGION
AWS_REPORTING_BUCKET_NAME
AWS_SECRET_ACCESS_KEY
HMRC_API_HOST
HMRC_CLIENT_ID
HMRC_CLIENT_SECRET
TARIFF_FROM_EMAIL
TARIFF_MANAGEMENT_EMAIL
TARIFF_SUPPORT_EMAIL
TARIFF_SYNC_EMAIL
TARIFF_SYNC_HOST
TARIFF_SYNC_PASSWORD
TARIFF_SYNC_USERNAME
GREEN_LANES_UPDATE_EMAIL
GREEN_LANES_NOTIFY_MEASURE_UPDATES
```

Temporary AWS credentials also require `AWS_SESSION_TOKEN`. Keep credentials
outside Git. For local work, use an ignored environment file or your approved
credential mechanism. Do not copy production secrets into tracked defaults.

Imports can change tariff data, write reports and send notifications. Confirm
the target database, buckets and email recipients before running jobs. A local
Rails process can still contact shared services if configured with their URLs
and credentials.
