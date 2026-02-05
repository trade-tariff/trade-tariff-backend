# Search Instrumentation (AI-148)

## Architecture

Uses the proven `LabelGenerator` pattern: `ActiveSupport::Notifications` instrumentation module + `LogSubscriber` that outputs JSON to `Rails.logger`.

- **`Search::Instrumentation`** (`app/lib/search/instrumentation.rb`) — module with `module_function` methods wrapping `ActiveSupport::Notifications.instrument`
- **`Search::Logger`** (`app/lib/search/logger.rb`) — `ActiveSupport::LogSubscriber` that converts events to JSON log entries with `service: "search"` and `timestamp`
- **`SearchResultTracking`** (`app/controllers/concerns/search_result_tracking.rb`) — concern for goods nomenclature controllers, fires `result_selected` when `request_id` param is present

## Events

| Event | Payload | Level | Where fired |
|-------|---------|-------|-------------|
| `search_started.search` | `request_id`, `query`, `search_type` | info | `Api::Internal::SearchService#call`, `Api::V2::SearchController#search` |
| `query_expanded.search` | `request_id`, `original_query`, `expanded_query`, `reason`, `duration_ms` | info | `Api::Internal::SearchService#expand_query` |
| `api_call_completed.search` | `request_id`, `model`, `duration_ms`, `response_type`, `attempt_number` | info | `InteractiveSearchService#call` |
| `question_returned.search` | `request_id`, `question_count`, `attempt_number` | info | `InteractiveSearchService#questions_result` |
| `answer_returned.search` | `request_id`, `answer_count`, `confidence_levels`, `attempt_number` | info | `InteractiveSearchService#answers_result`, `single_result_answer`, `best_available_answers` |
| `result_selected.search` | `request_id`, `goods_nomenclature_item_id`, `goods_nomenclature_class` | info | `CommoditiesController#show`, `HeadingsController#show`, `ChaptersController#show`, `SubheadingsController#show` (via `SearchResultTracking` concern) |
| `search_completed.search` | `request_id`, `search_type`, `total_attempts`, `total_questions`, `final_result_type`, `total_duration_ms`, `result_count` [+ `results_type`, `max_score` for classic] | info | `Api::Internal::SearchService#call`, `Api::V2::SearchController#search` |
| `search_failed.search` | `request_id`, `error_type`, `error_message`, `search_type` | error | `InteractiveSearchService#call` rescue, `ExpandSearchQueryService#expand_query` rescue |

## Wave 1 (this PR) — Backend instrumentation

- All events above implemented and tested
- `SearchInstrumentationService` removed (replaced by `Search::Instrumentation` + `Search::Logger`)
- `result_selected` backend wired — fires when `request_id` param present on goods nomenclature show actions
- Classic search `search_completed` includes `results_type` and `max_score` (parity with old instrumentation)

## Wave 2 — Frontend request_id propagation

- Frontend generates `request_id` (or receives it from the internal search response meta) and passes it:
  - As a query param when navigating to commodity/heading/chapter/subheading pages (enables `result_selected` correlation)
  - To the V2 classic search endpoint (enables end-to-end tracing for classic path)
- Add idle timeout (100s) — if no interaction for 100s, treat the search journey as abandoned
- Consider adding `request_id` to search suggestion requests for full classic path tracing

## Wave 3 — Terraform CloudWatch dashboard

Dashboard widgets (all answerable from Wave 1 events):

| Widget | Query source |
|--------|-------------|
| Search volume over time | `search_started` count, grouped by `search_type` |
| API latency distribution | `api_call_completed.duration_ms` |
| Questions per journey histogram | `search_completed.total_questions` |
| Completion rate | `result_selected` count / `search_started` count (requires Wave 2 for full accuracy) |
| Confidence distribution | `answer_returned.confidence_levels` |
| Error summary by type | `search_failed` count, grouped by `error_type` |
| Model usage breakdown | `api_call_completed.model` |
| Classic vs interactive comparison | All events filtered by `search_type` |
| Result selection rate | `result_selected` count / `search_completed` count |
