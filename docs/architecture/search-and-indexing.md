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

Public ATAR keywords and derived facts are excluded from OpenSearch documents, OpenSearch queries, and composite search embeddings unless the `search_atars_enabled` admin configuration is enabled. The setting defaults to `false`. After changing it, rebuild both search representations so stored documents and embeddings match the configured value:

```sh
# Wait at least 150 seconds after changing the setting so the production
# admin-configuration cache has expired.
INDEX=Search::GoodsNomenclatureIndex bin/rake opensearch:search:recreate
bin/rake search_embeddings:generate
```

Relevant code paths include:

- `app/services/generate_self_text/`
- `app/services/label_service.rb`
- `app/services/label_suggestions_updater_service.rb`
- `app/services/hybrid_retrieval_service.rb`
- `app/services/vector_retrieval_service.rb`
- `app/workers/generate_self_text_worker.rb`
- `app/workers/relabel_goods_nomenclature_worker.rb`
- `app/workers/goods_nomenclature_reconciliation_worker.rb`

## Hybrid Query Guardrail

Hybrid retrieval can apply a query-level quality guardrail after both retrieval legs have completed and before results are returned. It uses the highest raw vector similarity for an eligible commodity, before the separate per-candidate vector threshold is applied.

The guardrail is controlled through admin configuration:

- `hybrid_query_guardrail_enabled` defaults to off, preserving the existing hybrid behaviour.
- `hybrid_query_guardrail_threshold` defaults to `32`, representing a similarity of `0.32`.

When enabled, hybrid retrieval returns no suggestions if the maximum score is below the threshold, no eligible vector candidate exists, or the vector leg is unavailable. The `query_guardrail_decided.search` instrumentation event records the effective variant, score, threshold, outcome, and reason so A/B-test results can be attributed to the control.

Guided classification search can also attach bounded chapter- and section-note evidence to retrieved candidates. [Tariff knowledge notes](../tariff-knowledge-notes.md) documents extraction, graph edges, compressed-note materialisation and deduplication, prompt selection, and request-ID diagnostics.

## Query Expansion Deadline

Uncached guided-search query expansion has a fixed five-second operation-specific deadline.

The deadline covers the OpenAI connection, response wait, retry backoff, and all retry attempts. Each attempt receives only the operation's remaining budget. When the deadline expires, expansion returns the original query and conditional search retains its preliminary retrieval. No background work continues, so a late response cannot populate the expansion cache or start another retrieval.

Expected deadline fallback emits `query_expansion_timed_out` rather than `search_failed`. Its structured fields are `request_id`, `search_type`, `timeout_ms`, `elapsed_ms`, `model`, and `fallback_outcome`; the event does not contain the query. `fallback_outcome` is `original_query`, which is the direct result of the expansion service. Conditional search can then retain its preliminary retrieval. Use expansion-specific `api_call_completed` events as the uncached-attempt denominator and `query_expansion_timed_out` as the timeout numerator. End-to-end latency remains available as `total_duration_ms` on `search_completed`.

Example CloudWatch Logs Insights queries for rollout monitoring:

```text
filter service = "search"
  and (event = "query_expansion_timed_out"
       or (event = "api_call_completed" and operation = "search_query_expansion"))
| fields if(event = "query_expansion_timed_out", 1, 0) as timeout,
         if(event = "api_call_completed", 1, 0) as uncached_expansion
| stats sum(timeout) as timeouts,
        sum(uncached_expansion) as uncached_expansions,
        100.0 * sum(timeout) / sum(uncached_expansion) as timeout_rate_pct
```

```text
filter service = "search" and event = "search_completed" and search_type = "interactive"
| stats pct(total_duration_ms, 50) as p50_ms,
        pct(total_duration_ms, 95) as p95_ms,
        pct(total_duration_ms, 99) as p99_ms
```

Validate the behaviour in staging before production. Record the timeout count/rate, end-to-end p50/p95/p99, and a sample of the preliminary-result quality.
