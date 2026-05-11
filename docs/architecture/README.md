# Architecture

These pages give a code-level map of the Trade Tariff Backend. They describe stable boundaries rather than every model and endpoint.

## Pages

- [System overview](system-overview.md)
- [Platform context](platform-context.md)
- [Request routing](request-routing.md)
- [Data import and sync](data-import-and-sync.md)
- [Search and indexing](search-and-indexing.md)
- [Caching and background jobs](caching-and-background-jobs.md)
- [API documentation](api-documentation.md)

## Source Anchors

Start from these files when verifying architecture claims:

- `Gemfile`
- `config/routes.rb`
- `app/engines/`
- `app/lib/trade_tariff_backend/config.rb`
- `app/lib/tariff_synchronizer.rb`
- `app/lib/cds_synchronizer.rb`
- `app/lib/taric_synchronizer.rb`
- `app/services/search_service.rb`
- `config/sidekiq.yml`
- `lib/tasks/`

## Internal Context

For wider OTT context outside this repository, see [Confluence references](../confluence.md). Treat the repo and CI configuration as authoritative where Confluence and code disagree.
