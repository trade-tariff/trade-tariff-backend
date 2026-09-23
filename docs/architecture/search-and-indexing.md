# Search and Indexing

Search combines direct code lookup, OpenSearch-backed fuzzy matching, search references, suggestions, and generated classification content.

For trader outcomes, response metadata, combined failures and warning policy, use the canonical [AI-assisted search resilience contract](../search-resilience.md).

For the backend-only asynchronous testing API, payload state machine and polling contract, see [Queued internal search](queued-internal-search.md). Existing synchronous search callers are unchanged.

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

When enabled, hybrid retrieval returns no suggestions if the maximum score is below the threshold or no eligible vector candidate exists. If vector retrieval is unavailable, OpenSearch results remain available. If OpenSearch is unavailable, vector results are returned only when they pass the guardrail. The `query_guardrail_decided.search` instrumentation event records the effective variant, score, threshold, outcome, and reason so A/B-test results can be attributed to the control.

Guided classification search can also attach bounded chapter- and section-note evidence to retrieved candidates. [Tariff knowledge notes](../tariff-knowledge-notes.md) documents extraction, graph edges, compressed-note materialisation and deduplication, prompt selection, and request-ID diagnostics.

## Search Failure Diagnostics and Alarms

Recoverable failures emit `search_stage_failed` with a scalar `failure_code`, the operation, the error type, and a bounded error message. They can be followed by `search_completed` when fallback succeeds. `search_failed` is reserved for a failure escaping the instrumented search boundary. Hybrid retrieval also records each leg's outcome and failure code. A successful retrieval returning no matches is not a retrieval failure.

`terraform/degradation_alarms.tf` defines one alarm for each component when `enable_alarms` is enabled:

| Component | Failure events counted |
| --- | --- |
| OpenSearch | `search_stage_failed` with `opensearch_failed`, including direct and classic search, or an unsuccessful OpenSearch retrieval leg |
| Embedding generation | `embedding_api_call_failed` for `vector_search_query_embedding`, including malformed embedding responses |
| LLM | An unsuccessful `api_call_completed`, or `search_stage_failed` with `query_expansion_failed`, `interactive_search_failed`, or `duplicate_question_validation_failed`, including unusable responses |
| Vector database retrieval | `search_stage_failed` or an unsuccessful vector retrieval leg with `vector_retrieval_failed`; embedding failures belong to the separate embedding alarm |

These alarms count failure events and trigger when any matching event occurs in a five-minute period. They are not degraded-request counts: correlated stage and leg/API events can count the same failure more than once. Embedding failures are matched only at their API boundary to avoid counting their vector-leg fallback again. Investigate with the Search Operations dashboard and the event's `request_id`, `failure_code`, `operation`, and error fields.

The existing OpenSearch-leg and LLM API-error patterns remain alongside the new stage patterns so older application instances retain their alert coverage during a rolling deployment or rollback. The new vector alarm and unusable-response coverage require the corresponding new application events. Legacy vector errors cannot distinguish embedding generation from database retrieval and are not assigned to the database alarm.

## Search Failure Fields

Search events and search-related AI usage events include `search_degraded` and six explicit boolean fields: `query_expansion_failed`, `embedding_generation_failed`, `vector_retrieval_failed`, `interactive_search_failed`, `duplicate_question_validation_failed`, and `opensearch_failed`. Each field is present as `true` or `false`. Duplicate-question validation failing open has its own code, separate from interactive inference failure. Disabled stages, successful empty results, and query-guardrail decisions do not mark a search as degraded.

Flags describe failures known when each event is emitted. A later failure does not rewrite earlier events. Hybrid completion combines the retrieval legs' flags after both finish. An unclassified hard failure emits `search_failed` with `search_degraded: true` while all stage flags remain false.

Search Operations uses metrics for operational trends. Its linked Diagnostics dashboard keeps terminal failures, recovered stage failures, expansion timeouts and failed AI calls visible in the Recent Error Log. See [Search dashboards](../search-dashboards.md) for metric definitions and counting rules. General AI cost accounting continues to include billed failures.

To exclude degraded journeys from an experiment cohort, correlate all events sharing a `request_id` within the selected time window. Filtering individual events on `search_degraded` would retain costs and latency recorded before a later failure. The failure fields do not change dashboard cohorts by themselves.

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

## Query Expansion Strategies

The `expand_search_decider` admin configuration selects the conditional-expansion strategy:

- `v1` is the default. It preserves the existing behaviour, selecting AI expansion for uppercase acronym-like tokens as well as weak retrieval evidence.
- `v2` applies the targeted rules in `config/search_synonyms.txt` to retrieval queries and selects AI expansion from retrieval evidence without treating casing as a signal.

Selecting `v2` does not disable AI expansion. Queries with no significant tagged words, too few preliminary results, or a low top score continue through the normal AI-expansion path and retain the five-second deadline.

Mechanical synonyms are applied to both OpenSearch and vector retrieval. The interactive-search context retains the original query, or the AI-expanded semantic query when evidence-based expansion runs. Per-leg retrieval telemetry records the effective synonym-expanded query.

The synonym file accepts equivalent rules and directional rules:

```text
term, equivalent term
input phrase => input phrase, lexical alternative
```

Rules are matched case-insensitively against complete terms or phrases. Keep mappings contextual: prefer `HEPA filter` or `USB connector` to broad rules for `HEPA` or `USB`.

### Stored daily admin analytics

The admin search analytics endpoint reads matching query results from PostgreSQL. Each stored query contributes the days that still match its current fingerprint. A missing or stale group is a coverage gap for that widget, not a reason to hide the others. The endpoint does not submit CloudWatch queries on page reads and does not fall back to rolling snapshots. The daily 04:00 schedule invokes `SearchAnalyticsQueryWorker` without arguments to queue only missing or changed queries for yesterday. Supplying a UTC date string selects that day; child jobs on the same worker execute individual queries. Per-query jobs have no automatic retries and reuse successful results; failed queries leave an explicit coverage gap.

UK collection also stores `frontend_events` from the frontend's `guided_search.journey` messages. These messages have a Rails text prefix, so the query extracts their JSON explicitly. It stores hashed journey IDs, bounded event counts, reported question counts and submission-to-visible timing. It also stores result rank, confidence, and a second hash of `browser_session_id` values that match `v1:` plus 64 lowercase hex characters. Raw session identifiers and raw messages are not stored. This ninth group has separate coverage: missing frontend results do not hide the other groups. XI and the Classic view do not expose these UK guided events. Rendered and browser-visible events remain separate, and recorded actions are not unique clicks, completion rates or evidence of abandonment.

`journey_outcomes` adds compact, hashed identifier sets for backend outcomes in bounded windows, including the backend `total_questions` value for each set. It joins the same frontend start IDs used by Search requests, so admin lookups and repeated question steps do not inflate the outcome trend. The latest terminal window determines completed, failed or conflicting status; question-only and unobserved journeys remain explicit. Selections and empty results are overlapping indicators. Outcomes are attributed to existing start buckets, and range totals are independently deduplicated. Outcome records are read one day at a time. The outcome trend uses every stored outcome day, including rows from an older fingerprint when the terminal fields still combine. Range totals and question counts wait until every journey day has a current outcome fingerprint, rather than falling back to request-step counts. Other request-based metrics retain their existing definitions. This gives ten query groups for UK and nine for XI. The stored `ai_cost_trend` rows also keep the model name with each operation.

For initial population or a manual rerun, use `bundle exec rake search_analytics:collect_day`. `REPORTING_DATE=YYYY-MM-DD` selects a completed UTC day, `QUERIES=volume,ai_cost_trend` limits the selection, and `FORCE=true` (or `FORCE=1`) explicitly replaces selected successful results. Without a selection, all daily groups are considered. Initial deployment needs at least one matching stored group before the endpoint can serve data; until then it returns 404. Longer ranges and later query changes report per-query coverage. Missing days are not treated as zero traffic. No automatic historical backfill is started. Drain any previously queued `SearchAnalyticsSnapshotWorker` jobs before rollout; that obsolete worker and refresh service are removed. The old snapshot table is left untouched but no longer read.

For a range, `bundle exec rake search_analytics:backfill` defaults to `DAYS=30`: yesterday through 30 days ago, inclusive, newest first. It queues one coordinator per incomplete or stale day; each coordinator queues only the query groups still missing when it starts. `DAYS=1` collects yesterday only, and `FORCE=true` queues replacements for every group in the requested range without deleting the existing successful results first. `DAYS` must be an integer from 1 to 366. The task does not wait for CloudWatch. Queued jobs and stored successes are independent of the Rake process; an interrupted in-flight query may still require an explicit gap-fill run because automatic retries remain disabled.

The existing search-count field now counts distinct frontend-origin search-start IDs across the selected dates. AI costs include all recorded calls for those IDs inside the same dates. The total and operation breakdown both derive from the single stored `ai_cost_trend` query; no separate cost-summary query is collected. Other rates retain their request-based denominators. Optional `from` and `to` parameters select inclusive UTC dates, at most 366 days and ending yesterday or earlier; invalid ranges return 400.

### Search analytics SQL cohorts

Stored admin analytics exclude every event for a request ID with a recorded `search_degraded: true`, `search_failed`, or `search_stage_failed` search event in the selected time window. The snapshot failure lookup uses the same UK/XI log stream as its metrics. Missing, null, and empty request IDs remain included, as do historical requests without a linked failure. Use the complete journey window: a failure outside that window cannot exclude an event inside it. Search Overview does not use that cohort: it counts `TradeTariff/Search` metrics as each event is recorded and does not retract an earlier count when a later failure is linked. Operations also counts events through metrics. Quality, Experiment, and general AI Costs retain their existing log cohorts.

The shared `request_exclusion_filter.sql.tftpl` contains the SQL predicate used by Ruby and Terraform, with no inner row limit. Two-stage cost and selection queries place the failure lookup beside the request aggregation subquery to respect CloudWatch SQL's one-level nesting limit. Snapshot payload fields and millisecond units remain unchanged. Overview latency metrics are stored in seconds. SQL percentiles use fractions and can differ slightly from QL's approximate percentiles.

Development validation renders the real Terraform widget queries with `search_analytics:render_dashboard_queries`, then executes them and all distinct daily collector queries with `search_analytics:validate_cloudwatch_queries`. The superseded rolling snapshot definitions are not included in this validation catalog. Both tasks use `CLOUDWATCH_QUERY_VALIDATION_LOG_GROUP`; `CLOUDWATCH_DASHBOARD_QUERIES_FILE` connects rendering to validation. Rendering does not access AWS. Validation preserves native QL query languages and uses SQL for migrated consumers. AWS documents SQL log widgets through [LogQueryLanguage](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudwatch.LogQueryLanguage.html) and [LogQueryWidgetProps](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudwatch.LogQueryWidgetProps.html).

SQL dashboard widgets retain the `SOURCE 'group' |` envelope produced by the [AWS CDK implementation](https://github.com/aws/aws-cdk/issues/34482). The validator checks that source and every SQL FROM group, then removes only the leading dashboard envelope before StartQuery. Direct snapshot SQL obtains its group from FROM. Widget serialization follows that supported representation; validation does not publish a dashboard.
