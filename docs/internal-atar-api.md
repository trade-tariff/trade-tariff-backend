# Internal ATAR API

The UK internal API exposes the public Advance Tariff Ruling records imported and owned by this service. Its intended consumer is the separate `classification-testing-suite` repository, which performs evaluations outside-in. As with the other internal endpoints, the deployment must restrict this namespace to approved internal callers.

This boundary is deliberate: Trade Tariff Backend supplies source records, while evaluation case selection, orchestration, scoring, result storage, and reporting remain outside this repository.

## Endpoints

- `GET /uk/internal/atars` returns rulings ordered by ascending ATAR reference.
- `GET /uk/internal/atars/:ref` returns one ruling or a `404` response.

The endpoints are available only in UK service mode and are not mounted under `/xi/internal`.

The collection supports these query parameters:

- `page`: a positive page number; invalid or non-positive values use page 1. Requests where `page` and `per_page` would produce an offset over 1,000,000 return `400`.
- `per_page`: between 1 and 250; the default is 100 and larger values are capped at 250.
- `refs`: one or more exact, comma-separated ATAR references, limited to 250. A supplied empty filter or a filter over the limit returns `400`.

Pagination metadata is returned under `meta.pagination` with `page`, `per_page`, and `total_count`.

## Resource contract

Each JSON:API `atar` resource uses the ruling reference as its ID and exposes:

- `ref`
- `commodity_code`
- `goods_nomenclature_item_id`
- `description`
- `justification`
- `keywords`
- `validity_start_date`
- `validity_end_date`
- `source_url`
- `fetched_at`
- `updated_at`

Import payloads in `raw_fields` and any evaluator-derived state are intentionally excluded.

`fetched_at` and `updated_at` are ingestion freshness metadata. They can change when the importer runs and must not be used as stable source content when comparing evaluation cases.
