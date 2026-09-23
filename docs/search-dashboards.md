# Search dashboards

The Search team owns these dashboards. Start with **Search Operations** for errors and latency, **Search** for traffic, **Search Quality** for empty results and selections, and **Search Experiments** for a selected experiment. Follow the **Diagnostics** link from Operations to investigate individual requests.

## Metrics and coverage

Search and Search Operations use `TradeTariff/Search` metrics for operational trends. Operations does not scan logs. Search Overview also runs one log query for active experiment sessions. The backend emits Embedded Metric Format records from search notifications. Writes are best effort and do not block search. Missing telemetry is not zero traffic. Metrics can take about a minute to appear and have no backfill before their emitter is deployed. Operation, retrieval, guided-request health and validator-only series start when their emitters are deployed; older overview series keep their existing history. Do not join new numerator series to older denominator series.

Metric charts in Overview and Operations keep UK and XI separate, including percentiles. Do not average their percentiles or add different dimension rollups of the same metric. Operations trends use fixed five-minute periods. Summary values and bar charts aggregate over the entire selected range.

Metric counts are events, not unique requests, journeys or people. Every emitted event counts, including repeated steps and degraded searches. A later failure does not remove an earlier count. Admin analytics uses a different, failure-excluded cohort. Quality retains its counting rules, using metrics for two count widgets. Experiments retains its log-based cohorts.

| Metric | Source and meaning |
| --- | --- |
| `SearchEvents` | One per `search_completed` or `search_failed`, split by outcome. A completed search can still return an error outcome. |
| `SearchDuration` | Completed-search `total_duration_ms`, converted to seconds. |
| `AiApiDuration` | Every `api_call_completed` duration, including errors, in seconds. Overall and operation-specific dimension sets. |
| `AiApiCalls` | Every `api_call_completed`, split by operation and response type. The duplicate retry chart counts calls, not HTTP transport retries. |
| `GuidedSearchErrors` | One per terminal interactive/internal event: one for an exception or returned error, zero otherwise. Sum counts errors; SampleCount counts finished requests; Average times 100 is the error percentage. |
| `GuidedSearchDuration` | Completed interactive/internal server request duration in seconds, including returned errors. Exceptions have no duration sample. Not a whole browser journey. |
| `GuidedSearchOutcomes` | One per terminal interactive/internal event, split into answers, questions, error, hard_failure, unknown or other. Missing and unexpected outcomes are not labelled as success. |
| `QueryExpansions`, `QueryExpansionDuration` | Each `query_expanded` event and its duration in seconds. Includes cached results, unchanged queries and fallback; it does not imply successful AI expansion. |
| `QueryExpansionTimeouts` | One per `query_expansion_timed_out`. A timeout can also produce an AI API error; do not add those charts to count affected requests. |
| `RetrievalDuration` | Every `retrieval_leg_completed` duration in seconds, split by leg. Includes errors. |
| `RetrievalFailures` | One for an errored retrieval leg, zero for a successful leg. Unknown statuses do not emit a failure sample. |
| `RetrievalResultCount` | Result count from successful retrieval legs only. Zero matches is a valid success, not a failure. |
| `DuplicateValidatorFailOpen` | Only checks with `suspicious=true`. One for `reason=validator_unparseable`, zero otherwise. Average times 100 is the fail-open percentage of validator-eligible checks. SampleCount is its denominator. No eligible checks means no percentage. |
| `ResultSelections` | One per result-selection event, not a unique user or completed journey. |
| `ResultCount`, `CommodityResultCount` | Counts on completed searches. Missing or invalid counts do not emit samples. |
| `EmptyResults` | Completed searches satisfying the empty-result rules below. |

Durations and result counts must be finite, non-negative numbers. Metric dimensions use fixed lists for request source, search type, guided outcome, operation, response type and retrieval leg. Missing labels become `unknown`; unexpected labels become `other`. Request IDs, model names, queries, error messages, error classes and free-text expansion reasons are not metric dimensions.

## Operations layout and interpretation

Start with request health, then inspect dependencies and supporting behaviour. The health section includes both `interactive` and `internal` search types and excludes classic, evaluation and classification terminal events. Each finished request contributes one error sample and one outcome sample. Repeated terminal events count again. A request that returns questions is not a completed user journey. Returned errors and exceptions are disjoint terminal outcomes, so the error percentage does not count stage failures again.

Request volume and error percentage come from the same binary samples and share the same collection cutoff. Zero means observed requests without recorded errors; no requests means no percentage. Unknown outcomes remain visible separately and do not prove success. The health summaries use the selected range, not the latest five-minute bucket. Latency includes only completed requests, so it must be read beside errors and volume.

Dependency charts include shared search callers, including evaluations. They are not restricted to the health section's population. AI latency is separated into expansion, question/answer generation and final-answer generation. Error counts by operation include duplicate validation and retries. Expansion fallback, retrieval failures and AI errors can refer to the same request; do not add them to count affected requests. Successful-leg result counts are supporting evidence, not a service-health target.

UK series use blue and XI series use orange where colours are assigned. Percentile shades and labels distinguish distributions without pooling services. Trends label bucket counts as events per five minutes, not events per second. Percentages use a 0-100 axis and have adjacent volume charts. Request latency retains p99; smaller dependency populations use p50/p90, which can still be noisy at low volume. No operational thresholds or new alarms are implied.

## Metric reuse in Quality

Quality reuses existing metrics for two widgets, without adding metric series:

- **Searches vs Selections** sums completed `SearchEvents` and `ResultSelections` in one-hour buckets. It excludes failed searches, counts repeated events and includes events without request IDs. Each series combines UK and XI, as the original log query does.
- **Empty Commodity / Empty Results by Search Type** sums `EmptyResults` across UK and XI, separately for classic, interactive and internal searches. The pie uses the entire selected window, not only its latest period.

These charts reuse the overview metrics' existing history. They cannot show events before those metrics began collecting. A range that crosses that cutoff has partial coverage. Metric writes are best effort, so counts can differ from logs when records are dropped; metric aggregation and timestamp boundaries can also differ from log queries. Gaps are not filled with zero.

Other Quality widgets stay on logs. Existing metrics cannot reproduce the combined UK/XI median, free-text cohorts, result-type breakdowns or request details. Experiment labels, AI costs and generator events also lack equivalent search metric dimensions or values. Reusing broader counts would change those measurements.

## Empty-result rules

- Classic fuzzy or null searches are empty when they return zero commodity matches, even if headings or chapters are present. Exact classic matches are excluded when the commodity count is present. Historical events without a commodity count fall back to `result_count=0`.
- Interactive and internal searches are empty when `result_count=0`.
- Missing result counts are not observed zeroes.
- Quality separates completely empty results from results containing only non-commodity hits.
- Free-text rates exclude queries made only of digits, spaces, dots and hyphens. The classic denominator is non-exact free-text searches; the interactive denominator is free-text guided searches.

## Active experiment sessions

Search Overview shows **Active browser sessions by experiment** as a bar chart. It counts distinct valid `browser_session_id` values on frontend `guided_search.journey` events with `schema_version=1` and `outcome=page_visible`, grouped by the recorded experiment label over the entire selected range. Repeated page events within a label count once. It combines frontend activity across UK and XI and does not sum per-hour distinct counts.

The chart excludes missing, null or blank experiment labels and absent or malformed session IDs. It shows the top 30 labels by estimated session count, including labels not known to the backend. Counts can be approximate at high cardinality. No matching events means no observations, not proof that nobody is enrolled.

This is observed activity, not a count of people, current enrolments or configured experiments. The frontend records the most recently enrolled active experiment label, not every enrolment held by a session. A session can appear under different labels during the range, so the bars are not mutually exclusive and must not be summed as unique people. Cookie resets, session expiry and missing browser telemetry affect coverage. There is no explicit bot exclusion; events measure accepted browser telemetry.

This widget scans logs on each refresh and has only the history retained in those logs. It creates no custom metric dimensions. Use the linked Experiments dashboard to investigate a label.

## Diagnostics and experiments

`SearchOperations-<environment>-Diagnostics` keeps exact error types, expansion reasons and recent-event tables in Logs Insights. It defaults to the last hour and limits each table to 30 rows. A row limit does not limit bytes scanned. Use a narrow time range and copy a request ID into admin search diagnostics for a full trace. Recent errors include hard failures, stage failures, timeout fallback, interactive error outcomes and failed AI calls. Correlated rows can describe the same failure.

Experiment widgets use the selected experiment label and dashboard time range. One guided-search browser session can contain multiple requests. Session counts can be approximate at high cardinality, are not people, and are not additive across time buckets. Browser-visible events and server-observed events measure different things. A selected range does not establish complete browser history.

No dashboard change applies AWS resources itself. Terraform manages the dashboard definitions; application deployment supplies new metric series. Charts remain empty until those series arrive.
