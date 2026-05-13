# Search and Indexing

Search combines direct code lookup, OpenSearch-backed fuzzy matching, search references, suggestions, and generated classification content.

## Request Flow

Public search routes are defined in `app/engines/v2_api.rb`:

- `GET /search`
- `POST /search`
- `GET /search_suggestions`

`app/services/search_service.rb` is the main entrypoint for public search. It normalises the query, tries an exact search for numeric identifiers, falls back to fuzzy search, and returns a null search result for empty or blocked queries.

## Search Components

- Exact/fuzzy search classes live under `app/services/search_service/`.
- Search query objects live under `app/queries/search/`.
- Search index definitions live under `app/indexes/search/`.
- Search serializers live under `app/serializers/search/` and `app/serializers/api/v2/`.
- Search instrumentation and logging live under `app/lib/search/`.

## OpenSearch Operations

OpenSearch Rake tasks live in `lib/tasks/opensearch.rake`:

- `opensearch:search:recreate INDEX=model_name`
- `opensearch:search:recreate_all`
- `opensearch:cache:recreate INDEX=model_name`
- `opensearch:cache:recreate_all`

The higher-level `tariff:reindex` task delegates to `TradeTariffBackend.reindex`.

## Generated Search Content

Generated self-texts, labels, and embeddings support search quality. The lifecycle is documented in [Generated classification content lifecycle](../generated-classification-content-lifecycle.md).

Relevant code paths include:

- `app/services/generate_self_text/`
- `app/services/label_service.rb`
- `app/services/label_suggestions_updater_service.rb`
- `app/services/hybrid_retrieval_service.rb`
- `app/services/vector_retrieval_service.rb`
- `app/workers/generate_self_text_worker.rb`
- `app/workers/relabel_goods_nomenclature_worker.rb`
- `app/workers/goods_nomenclature_reconciliation_worker.rb`
