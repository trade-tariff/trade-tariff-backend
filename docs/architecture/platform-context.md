# Platform Context

This backend sits inside the wider Online Trade Tariff platform. Confluence describes OTT as a public HMRC service that provides information needed when importing into and exporting out of the UK, alongside APIs for third-party software.

## Users and Consumers

The wider platform supports:

- Traders and intermediaries looking up commodity codes, duties, quotas, and controls.
- Internal HMRC users such as compliance officers.
- Individual consumers checking tariff information.
- Software developers integrating tariff data into third-party systems.
- Authenticated users using MyOTT-style personalised services.

## Business Capability Areas

The service catalogue groups OTT capabilities into areas that map back to this backend:

- Classification services: commodity search, tariff hierarchy browsing, classified goods, hard-to-classify guidance, and chemical search.
- Duty, tax, and measures services: duty/VAT lookup, reliefs and suspensions, trade remedies, import/export controls, quotas, customs procedures, and certificates.
- Origin and valuation services: Rules of Origin guidance, customs valuation guidance, and exchange rates.
- Personalised/account services: MyOTT subscriptions, notifications, and user-specific tariff changes.
- Data integration and developer services: public APIs, categorisation APIs, tariff changes feeds, and developer-facing integration support.
- Tariff updates and news: stop press notifications, live issues, trade news, and service updates.
- Northern Ireland and Internal Market services: Windsor Framework and Green Lanes categorisation.

## Runtime Platform

Confluence platform docs describe the applications as ECS Fargate services deployed through GitHub Actions, with PostgreSQL, Redis/Valkey, OpenSearch, CloudFront, S3, and AWS-managed secrets around them.

UK and XI run as separate web and Sidekiq services (`SERVICE=uk` / `SERVICE=xi`) against a single shared Postgres instance, split into `uk`, `xi`, and `public` schemas. `SERVICE` sets the connection's `search_path` (`config/database.yml`), so most Sequel models resolve to the schema matching whichever service is running. A small set of models opt out of this and are hardcoded to the `uk` schema instead (`Sequel::Model(Sequel[:table].qualify(:uk))`) - `AdminConfiguration` and the `Evaluation*` models - because that data is meant to be a single shared source of truth read and written by both services, not duplicated per schema. Migrations for those tables must run with the default `SERVICE=uk`; running them under `SERVICE=xi` creates the table in the wrong schema and leaves the xi service unable to find it.

For this repository, verify platform details in:

- `.github/workflows/`
- `terraform/`
- `config/routes.rb`
- `config/sidekiq.yml`
- `app/lib/trade_tariff_backend/config.rb`

Some Confluence AWS pages are marked as work in progress. Use them for orientation, not as a definitive implementation contract.
