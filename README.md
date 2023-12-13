# Trade Tariff Backend

The Trade Tariff Backend provides an API which allows to search commodity codes
for import and export for tax, duty and licences that apply to goods, from and
to UK and NI.

Projects using the Trade Tariff (TT) API:

- [Trade Tariff Frontend](https://github.com/trade-tariff/trade-tariff-frontend)
- [Trade Tariff Admin](https://github.com/trade-tariff/trade-tariff-admin)
- [Trade Tariff Duty Calculator](https://github.com/trade-tariff/trade-tariff-duty-calculator)

## Development

### Dependencies

- Ruby [v3.2](https://github.com/trade-tariff/trade-tariff-frontend/blob/main/.ruby-version#L1)
- Postgresql v13
- OpenSearch v2
- Redis

These can be configured by running `docker-compose up` or by manual installation.

### Setup

1. Clone this repo
2. Install the correct ruby version according to the `.ruby-version` - eg using
  `rbenv` or `asdf`.
3. Setup the app:
    - If you don't have a db dump then run `bin/setup` without parameters.
      - _NB: this will result in a empty dataset._
    - If you do have a database dump, run `bin/setup <path/to/dump/ file>`.
      Sidekiq is started to build the search indexes - once the jobs have all
      finished (10 `[done]` jobs, one after the other), hit `Ctrl-C` to exit
      sidekiq.
4. Start the app with `bin/rails s`.

### Database

If you have access, you can download a database dump from our environments.
Details of how to fetch a database dump are available on Slack.

To restore the database dump:

```sh
psql -h localhost tariff_development < tariff-merged-staging.sql
```

### Running an XI service

1. Add `SERVICE=xi` to `.env.development.local`
2. Rebuild the search indexes
   - `bin/rake tariff:reindex`
   - `bundle exec sidekiq`
3. Run the rails server as normal - `bin/rails s`

### Performing daily updates

These are run daily by a background job, `CdsUpdatesSynchronizerWorker` or
`TaricUpdatesSynchronizerWorker`. Additional environment variables are needed to
run these jobs locally.

These should be added to `.env.development.local`:

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
TARIFF_IGNORE_PRESENCE_ERRORS
TARIFF_MANAGEMENT_EMAIL
TARIFF_SUPPORT_EMAIL
TARIFF_SYNC_EMAIL
TARIFF_SYNC_HOST
TARIFF_SYNC_PASSWORD
TARIFF_SYNC_USERNAME
```

## Licence

Trade Tariff is licenced under the [MIT licence](https://github.com/trade-tariff/trade-tariff-backend/blob/main/LICENCE.txt)
