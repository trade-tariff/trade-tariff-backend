# AI-assisted search failure and fallback scenarios

Owner: AI-assisted search development team.

This is the canonical failure contract for AI-assisted search. Product and support colleagues can start with the outcomes below. Developers and operators can use the metadata, configuration and diagnostic sections to investigate a specific request.

## Trader outcomes

When a dependency fails, the trader stays in guided search. Where usable results remain, the service provides reduced guided search using the surviving retrieval source. It can remove questions and confidence without removing the results. Dependency recovery does not switch the trader to classic search.

Three outcomes must remain distinct:

- A completed search can return results or a question while recording a recovered failure.
- A completed search can legitimately return no results, including when a relevance guardrail rejects candidates. This is not by itself a dependency failure.
- A search with no successful retrieval source returns a controlled backend error. Other unrecovered exceptions can also terminate the request.

The following scenarios assume `retrieval_method=hybrid`, with usable surviving candidates. Questions can continue only when interactive search is enabled, the request has not skipped questions, and the remaining journey rules permit them.

| Scenario | Trader outcome and result source | Questions and confidence |
| --- | --- | --- |
| Expansion unavailable | Continue with the original wording, or retain preliminary retrieval when conditional expansion cannot improve it | Can continue |
| Query embedding unavailable | Show keyword/OpenSearch results in reduced guided search | Suppressed |
| Vector retrieval unavailable | Show keyword/OpenSearch results in reduced guided search | Suppressed |
| OpenSearch unavailable | Use meaning-based/vector results if they pass the hybrid guardrail | Can continue |
| Question or answer generation unavailable | Show keyword/OpenSearch results in reduced guided search | Suppressed |
| OpenSearch and question/answer generation unavailable | Show surviving vector results in reduced guided search | Suppressed |
| Both retrieval sources unavailable | Show the guided-search backend-error outcome; no results can be recovered | Unavailable |
| Duplicate-question validator unavailable | Retry eligible LLM errors using the shared client policy. If retries are exhausted, or validation returns unusable output, allow the proposed question and record the failure in response metadata and diagnostics. No trader banner is configured. | Can continue |

## Response and diagnostic contract

Failure codes are defined in [Search::FailureCodes](../app/lib/search/failure_codes.rb). Successful internal and V2 classification responses include `meta.search_failures`, an array of all codes recorded during that HTTP request. Healthy requests return an empty array. Combined failures accumulate codes rather than replacing an earlier code; code order is not a client contract.

In the table below, the **metadata** column lists the codes in `meta.search_failures` for a successful response. **Flags** means `search_degraded: true` and a boolean field named after each recorded code set to `true` on subsequent search diagnostics. The other known stage flags are `false` unless those stages also failed. Earlier events are not rewritten when a later stage fails.

| Scenario | Stable failure code(s) / metadata | Backend HTTP response | Log flags | Frontend warning policy |
| --- | --- | --- | --- | --- |
| Expansion unavailable or unusable | `query_expansion_failed` | 200 with surviving results/question, or empty results | Flags for this code | Configurable generic warning |
| Query embedding unavailable or unusable | `embedding_generation_failed` | 200 with OpenSearch results, or empty results | Flags for this code | Configurable generic warning |
| Vector retrieval fails | `vector_retrieval_failed` | 200 with OpenSearch results, or empty results | Flags for this code | Configurable generic warning |
| OpenSearch fails | `opensearch_failed` | 200 with eligible vector results/question, or empty results | Flags for this code | Configurable generic warning |
| Question/confidence generation fails or returns unusable output | `interactive_search_failed` | 200 with source-specific results, without interactive metadata | Flags for this code | Configurable generic warning |
| OpenSearch and interactive generation fail | `opensearch_failed`, `interactive_search_failed` | 200 with surviving vector results, without interactive metadata | Flags for both codes | One configurable generic warning |
| OpenSearch and query embedding fail | Request state records `opensearch_failed`, `embedding_generation_failed`; error response does not promise `meta.search_failures` | 500 controlled error | Flags for both codes; terminal `search_failed` | Guided-search error handling, not the successful-response banner contract |
| OpenSearch and vector retrieval fail | Request state records `opensearch_failed`, `vector_retrieval_failed`; error response does not promise `meta.search_failures` | 500 controlled error | Flags for both codes; terminal `search_failed` | Guided-search error handling, not the successful-response banner contract |
| Duplicate-question validator fails or returns unusable output | `duplicate_question_validation_failed` | 200; proposed question remains allowed | Flags for this code | No configured trader banner; failure remains in metadata and diagnostics |

Rows describe outcomes when the named stage is reached. For example, an empty retrieval finishes before interactive generation is attempted. Additional expansion or validation failures can coexist with the other codes; apply the surviving-source rules rather than inventing a new priority for each permutation.

The terminal retrieval error is:

```json
{
  "errors": [
    {
      "status": "500",
      "title": "Search failed",
      "detail": "Search is temporarily unavailable"
    }
  ]
}
```

This backend status does not specify the rendered frontend HTTP status. The frontend handles the backend error within guided search. Provider exception details are not part of this error response.

### Source selection and non-failure boundaries

- [HybridRetrievalService](../app/services/hybrid_retrieval_service.rb) waits for both retrieval legs, merges their diagnostics, and raises `AllLegsFailed` only when both legs error. A successful empty leg is still successful.
- If vector retrieval is unavailable, surviving OpenSearch results are retained even with the hybrid guardrail enabled. If OpenSearch is unavailable, vector candidates must still pass the guardrail. Both healthy sources remain subject to the configured guardrail and ranking rules.
- [Internal SearchService](../app/services/api/internal/search_service.rb) skips interactive generation after an embedding/vector failure. After interactive generation fails, it selects OpenSearch results for hybrid retrieval unless OpenSearch also failed, in which case it selects vector results. It removes the interactive response, including generated questions and confidence.
- With `retrieval_method=vector` or `opensearch`, there is no second retrieval leg to recover from. An interactive failure retains that configured source's candidates; a retrieval exception follows the normal error path.
- Disabled expansion, disabled interactive generation, exact matches, empty results and guardrail rejection do not themselves set a failure code. Frontend eligibility and rollout routing are separate from this dependency fallback contract.
- A malformed expansion cache entry records a failure and is evicted before a fresh attempt. A successful fresh attempt can therefore use expanded wording while still reporting `query_expansion_failed` for the recovered cache failure.

### Duplicate-question behaviour

The [duplicate-question guard](../app/services/interactive_search/duplicate_question_guard.rb) uses the shared OpenAI client, including its transport retry policy. If validation still errors or is malformed, it records `duplicate_question_validation_failed` and allows the proposed question. There is no additional retry loop in the guard for unusable validation output.

A confirmed duplicate is different: [InteractiveSearchService](../app/services/interactive_search_service.rb) requests another classifier response once. A second confirmed duplicate records `interactive_search_failed`, so the internal search service returns source-specific results without questions or generated confidence. A successful replacement question need not mark the request as failed.

The code is present in response metadata and backend diagnostics, but is not configured for a trader banner.

## Frontend warning ownership and journey state

The frontend owns warning presentation through [config/search_failure_messages.yml](https://github.com/trade-tariff/trade-tariff-frontend/blob/main/config/search_failure_messages.yml). Codes configured with `enabled: true` and `level: warn` share one warning banner. The [frontend translations](https://github.com/trade-tariff/trade-tariff-frontend/blob/main/config/locales/en.yml) own its heading and message.

Changing `enabled` controls a code's warning eligibility. The registry is application configuration, not a backend admin flag. Unknown codes are logged by the frontend and ignored for visible warnings. In particular, `duplicate_question_validation_failed` is unconfigured. Showing fewer warnings does not remove backend failure metadata or change retrieval behaviour.

[InteractiveSearchable](https://github.com/trade-tariff/trade-tariff-frontend/blob/main/app/controllers/concerns/interactive_searchable.rb) retains enabled warning codes in the session by journey request ID, merges them with later responses, and deduplicates them. A later healthy question response does not erase an earlier warning. Retention is bounded to the most recent journeys, and the current journey's stored warnings are cleared at terminal rendering or error handling. Configuration is reapplied when retained codes are read.

Backend [TradeTariffRequest](../app/lib/trade_tariff_request.rb) state is request-scoped and reset between HTTP requests. It does not accumulate the frontend's journey history. Hybrid retrieval explicitly propagates request context into its worker threads and merges their failures on completion.

## Retry and timeout boundaries

| Owner | Boundary and where to inspect configuration |
| --- | --- |
| [ExpandSearchQueryService](../app/services/expand_search_query_service.rb) | `EXPANSION_TIMEOUT_SECONDS` is an overall uncached expansion budget. It covers shared-client request/connect attempts and retry delays. On deadline expiry, expansion returns original wording; conditional search can retain preliminary retrieval. |
| [OpenaiClient](../app/lib/openai_client.rb) | Owns retryable transport/API errors, attempt and backoff constants, and rate-limit delays. Transport timeouts come from `TradeTariffBackend.openai_api_timeout` and `openai_api_open_timeout`. The expansion deadline is passed explicitly; do not assume it applies to classifier or validator calls. |
| [EmbeddingService](../app/lib/embedding_service.rb) | Owns embedding request validation, retries and transport behaviour. Inspect this separately from classifier retries and from database retrieval. |
| [OpenSearch configuration](../app/lib/trade_tariff_backend/config/opensearch.rb) and [OpensearchRetrievalService](../app/services/opensearch_retrieval_service.rb) | Own client configuration and the keyword retrieval failure boundary. Hybrid retrieval chooses the surviving source; it is not a general retry loop. |
| [DuplicateQuestionGuard](../app/services/interactive_search/duplicate_question_guard.rb) and [InteractiveSearchService](../app/services/interactive_search_service.rb) | Shared transport retries, validator fail-open handling and one classifier retry after a confirmed duplicate are separate decisions. |

Source constants and effective environment configuration are authoritative. Do not infer a whole-request latency guarantee from successful fallback handling: a dependency can consume the available request time before recovery is reached.

## Investigating a request

Use the appropriate environment and UK/XI log stream in CloudWatch Logs Insights. The following queries use the structured search fields. Choose a time window covering the whole journey.

Find request IDs with degraded search events, including unclassified terminal failures:

```text
fields @timestamp, request_id, event, failure_code, operation
| filter service = "search" and search_degraded = true
| stats count(*) as degraded_events, latest(@timestamp) as last_seen by request_id
| sort last_seen desc
```

Find events associated with a particular failure code using its boolean field. Replace `duplicate_question_validation_failed` with any of the six exact codes in the matrix:

```text
fields @timestamp, request_id, event, failure_code, operation, error_type, error_message
| filter service = "search" and duplicate_question_validation_failed = true
| sort @timestamp desc
```

Then inspect the complete request, including events before a failure was known:

```text
fields @timestamp, event, operation, failure_code, search_degraded, error_type, error_message
| filter service = "search" and request_id = "REQUEST_ID"
| sort @timestamp asc
```

`search_stage_failed` records a recovered or unrecovered stage failure with a scalar `failure_code`. A degraded request can end with `search_completed`; `search_failed` is the terminal unrecovered event. Expansion deadline expiry also has `query_expansion_timed_out` diagnostics. An unclassified hard failure sets `search_degraded: true` even if all six known stage flags remain false.

Event counts are not affected-request counts: several events can describe one failure. Search Overview and admin snapshots exclude correlated degraded requests; Operations, Quality, Experiment and general AI Costs retain their existing cohorts. Use the [search and indexing guide](architecture/search-and-indexing.md) for alarm coverage, query-expansion measurements and analytics cohort details.

## Verification and maintenance

Update this contract in the same change as failure-code, source-selection, warning-policy or retry-boundary changes. Keep the frontend documentation index linked here rather than maintaining a second matrix. Confluence provides a trader-outcome summary and links to this contract; existing operational procedures retain ownership of rollout and rollback steps.

Review against these source-backed examples:

- [Internal resilience specs](../spec/services/api/internal/search_service_resilience_spec.rb) and [internal service specs](../spec/services/api/internal/search_service_spec.rb): successful metadata and source-specific fallback.
- [Hybrid retrieval specs](../spec/services/hybrid_retrieval_service_spec.rb): both legs, surviving candidates, guardrails and combined failures.
- [Expansion specs](../spec/services/expand_search_query_service_spec.rb): deadline, malformed output and cache recovery.
- [Duplicate guard specs](../spec/services/interactive_search/duplicate_question_guard_spec.rb) and [interactive service specs](../spec/services/interactive_search_service_spec.rb): validator failure and confirmed-duplicate handling.
- [Internal request specs](../spec/requests/api/internal/search_controller_spec.rb) and [V2 request specs](../spec/requests/api/v2/classification_search_controller_spec.rb): HTTP response boundaries.

When changing behaviour, run the relevant full spec groups and verify the frontend journey.
