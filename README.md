# Trade Tariff Backend

Trade Tariff Backend provides tariff data and APIs for the
[Online Trade Tariff](https://www.gov.uk/trade-tariff). It imports tariff
updates and serves commodity codes, duties, measures, quotas, certificates and
rules of origin. It also supports search, reporting and staff administration.

This Ruby on Rails application uses Sequel and PostgreSQL for tariff data,
OpenSearch for search, and Redis and Sidekiq for background work. Each process
runs as either the UK service (`SERVICE=uk`) or the Northern Ireland service
(`SERVICE=xi`).

The main consumers are
[Trade Tariff Frontend](https://github.com/trade-tariff/trade-tariff-frontend),
which includes the duty calculator, and
[Trade Tariff Admin](https://github.com/trade-tariff/trade-tariff-admin).
For API consumers, start with the
[Trade Tariff API documentation](https://docs.trade-tariff.service.gov.uk/).

## Run locally

### Prerequisites

- Ruby at the version in [.ruby-version](.ruby-version) and Bundler.
- PostgreSQL with the [pgvector extension](https://github.com/pgvector/pgvector).
- OpenSearch and Redis.
- PostgreSQL, libyaml and zlib development libraries for native Ruby gems.
- A local PostgreSQL user that can create databases and install the required extensions.

Clone this repository, or follow the [fork workflow](CONTRIBUTING.md#fork-and-branch)
if you want to contribute without write access. See
[CI configuration](.github/workflows/ci.yml) for the backing services used in tests.

### Configure the application

Put overrides in `.env.development.local`, not in the tracked
[.env.development](.env.development). The defaults use `host.docker.internal`
for several backing services. If they run directly on your machine, set:

```dotenv
PGHOST=localhost
REDIS_URL=redis://localhost:6379
ELASTICSEARCH_URL=http://localhost:9200
```

`ELASTICSEARCH_URL` is the configuration name used for OpenSearch.
`DB_USER` defaults to `postgres`. See [config/database.yml](config/database.yml)
for database settings. Keep credentials out of Git and use only local or
explicitly authorised development services.

### Set up and start

On a new local database:

```sh
bin/setup
bin/dev
```

`bin/setup` installs Ruby dependencies, creates the database, loads its structure
and seeds, prepares the test database and queues search indexing jobs. It is not
a production-data installer: the seed data does not provide a complete tariff.
Do not use it to reinitialise a database you need to keep.

`bin/dev` starts Rails on port 3000 and a Sidekiq worker. The UK API root is
<http://localhost:3000/uk/api>. To run only the web process, use `bin/rails server`.

For journeys that need real tariff data, team members must obtain an approved
database dump through the team's access process. Do not commit or share dumps
in public issues. On a new local database, `bin/setup /path/to/dump.sql` restores
a plain SQL dump and starts Sidekiq to rebuild indexes. Stop Sidekiq after the
indexing jobs finish, then start `bin/dev`.

### Run the Northern Ireland service

Set `SERVICE=xi` in the environment of the XI process. It needs an XI dataset and
search indexes. Run `bin/rails tariff:reindex` and a Sidekiq worker with the same
`SERVICE` setting. If the UK process already uses port 3000, start the XI web
process on another port, for example `SERVICE=xi bin/rails server -p 3002`.

`SERVICE` controls the PostgreSQL schema. Some records, including
`AdminConfiguration` and evaluation records, are shared in the `uk` schema.
Run shared-table migrations with `SERVICE=uk`; running only XI migrations does
not create those shared tables. See [config/database.yml](config/database.yml)
and [architecture](docs/architecture/README.md) before changing service setup.

## Run checks

With PostgreSQL, Redis and OpenSearch available and the test database prepared:

```sh
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
bundle exec rake swagger:check_coverage
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for hooks and pull requests.
[GitHub Actions](.github/workflows/ci.yml) defines the CI checks.

## API documentation

Public V2 endpoint documentation comes from specs in
[spec/swagger/api/v2/](spec/swagger/api/v2/). Update those specs alongside request
specs when changing a public endpoint. Do not edit the generated
[OpenAPI document](swagger/v2/swagger.json) by hand.

To generate a local preview:

```sh
RAILS_ENV=test bin/generate-swagger
```

See the [API documentation guide](docs/architecture/api-documentation.md) for the
generation and CI workflow.

Internal/authenticated controllers (green lanes, notifications, etc.) are explicitly excluded in `lib/tasks/swagger.rake`.

## Find your way around

- [Documentation index](docs/README.md): architecture and domain guides.
- [Architecture](docs/architecture/README.md): routing, imports, search and background jobs.
- [Daily tariff updates](docs/daily-updates.md): integration prerequisites for maintainers.
- [Development and delivery](docs/development-and-delivery.md): team and deployment conventions.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) for reporting bugs, making a fork,
submitting changes and reporting security issues privately.

## Licence

The code and associated documentation are available under the
[MIT licence](LICENCE.txt), with the existing Crown copyright notice.
Keep the licence and copyright notice when you reuse the software.
Third-party dependencies and datasets retain their own terms; the software
licence is not a licence for every dataset the application can import.
