# Search dashboards

The Search team owns these dashboards. Start with **Search Operations** for errors and latency, **Search** for traffic, **Search Quality** for empty results and selections, and **Search Experiments** for a selected experiment. Follow the **Diagnostics** link from Operations to investigate individual requests.

## Metrics and coverage

Search and Search Operations read `TradeTariff/Search` metrics. Opening either dashboard does not scan logs. The backend emits Embedded Metric Format records from search notifications. Writes are best effort and do not block search. Missing telemetry is not zero traffic. Metrics can take about a minute to appear and have no backfill before their emitter is deployed. New operation and retrieval series start with the operations-metrics deployment; older overview series keep their existing history.

Overview and Operations keep UK and XI separate, including percentiles. Do not average their percentiles or add different dimension rollups of the same metric. All operations charts use five-minute periods.

Counts are events, not unique requests, journeys or people. Every emitted event counts, including repeated steps and degraded searches. A later failure does not remove an earlier count. Admin analytics uses a different, failure-excluded cohort. Quality retains its counting rules, using metrics for two count widgets. Experiments retains its log-based cohorts.

| Metric | Source and meaning |
| --- | --- |
| `SearchEvents` | One per `search_completed` or `search_failed`, split by outcome. A completed search can still return an error outcome. |
| `SearchDuration` | Completed-search `total_duration_ms`, converted to seconds. |
| `AiApiDuration` | Every `api_call_completed` duration, including errors, in seconds. Overall and operation-specific dimension sets. |
| `AiApiCalls` | Every `api_call_completed`, split by operation and response type. The duplicate retry chart counts calls, not HTTP transport retries. |
| `InteractiveSearchErrors` | One for an interactive completion with `final_result_type=error`, otherwise zero for that interactive completion. Hard failures are separate. |
| `QueryExpansions`, `QueryExpansionDuration` | Each `query_expanded` event and its duration in seconds. Includes cached results, unchanged queries and fallback; it does not imply successful AI expansion. |
| `QueryExpansionTimeouts` | One per `query_expansion_timed_out`. A timeout can also produce an AI API error; do not add those charts to count affected requests. |
| `RetrievalDuration` | Every `retrieval_leg_completed` duration in seconds, split by leg. Includes errors. |
| `RetrievalFailures` | One for an errored retrieval leg, zero for a successful leg. Unknown statuses do not emit a failure sample. |
| `RetrievalResultCount` | Result count from successful retrieval legs only. Zero matches is a valid success, not a failure. |
| `DuplicateGuardFailOpen` | One for a check with `reason=validator_unparseable`, zero for every other guard check. Its average times 100 is the fail-open percentage of all checks, not just validator calls. No checks means no percentage. |
| `ResultSelections` | One per result-selection event, not a unique user or completed journey. |
| `ResultCount`, `CommodityResultCount` | Counts on completed searches. Missing or invalid counts do not emit samples. |
| `EmptyResults` | Completed searches satisfying the empty-result rules below. |

Durations and result counts must be finite, non-negative numbers. Metric dimensions use fixed lists for request source, search type, operation, response type and retrieval leg. Missing labels become `unknown`; unexpected labels become `other`. Request IDs, model names, queries, error messages, error classes and free-text expansion reasons are not metric dimensions.

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

## Diagnostics and experiments

`SearchOperations-<environment>-Diagnostics` keeps exact error types, expansion reasons and recent-event tables in Logs Insights. It defaults to the last hour and limits each table to 30 rows. A row limit does not limit bytes scanned. Use a narrow time range and copy a request ID into admin search diagnostics for a full trace. Recent errors include hard failures, stage failures, timeout fallback, interactive error outcomes and failed AI calls. Correlated rows can describe the same failure.

Experiment widgets use the selected experiment label and dashboard time range. One guided-search browser session can contain multiple requests. Session counts can be approximate at high cardinality, are not people, and are not additive across time buckets. Browser-visible events and server-observed events measure different things. A selected range does not establish complete browser history.

No dashboard change applies AWS resources itself. Terraform manages the dashboard definitions; application deployment supplies new metric series. Charts remain empty until those series arrive.
