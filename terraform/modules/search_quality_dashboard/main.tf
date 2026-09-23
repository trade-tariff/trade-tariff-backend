locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SearchQuality-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""
  namespace      = "TradeTariff/Search"

  # Classic product-quality empty commodities: fuzzy/null searches with commodity_result_count = 0.
  # That is "Best commodity matches" empty. It includes both:
  #   - completely empty results (result_count = 0)
  #   - headings/chapters/other hits only (result_count > 0, commodity_result_count = 0)
  # Exact matches are never empty-commodity results, even when commodity_result_count is 0.
  # Historical classic logs without commodity_result_count fall back to result_count = 0.
  classic_empty_commodity_condition = "(search_type = \"classic\" and ((ispresent(commodity_result_count) and commodity_result_count = 0 and (not ispresent(results_type) or results_type != \"exact_search\")) or (not ispresent(commodity_result_count) and result_count = 0)))"

  # Classic completely empty bag (subset of empty commodities when the new field is present).
  classic_no_results_condition = "(search_type = \"classic\" and result_count = 0)"

  # Interactive empty results: result_count = 0.
  # Logs use search_type=interactive; keep "internal" in the filter for forward-compat only.
  interactive_no_results_condition = "((search_type = \"interactive\" or search_type = \"internal\") and result_count = 0)"

  # Shared rate/term widgets: classic uses empty-commodity metric; interactive uses no results.
  # Keep in sync with SearchAnalytics::CloudwatchSnapshotQuery#zero_result_condition
  # and the other search_*_dashboard modules.
  zero_result_condition = "(${local.classic_empty_commodity_condition} or ${local.interactive_no_results_condition})"

  # Free-text queries only (same regex as admin search_term_improvements analytics).
  # Digits, spaces, dots, and hyphens alone count as numeric/code lookups.
  non_numeric_query_condition = "(ispresent(query) and query not like /^[0-9 .-]+$/)"

  # Classic free-text fuzzy/null cohort (excludes exact code matches).
  classic_non_numeric_fuzzy_condition = "(search_type = \"classic\" and ${local.non_numeric_query_condition} and (not ispresent(results_type) or results_type != \"exact_search\"))"

  # Interactive free-text cohort. Guided search logs search_type=interactive today;
  # "internal" remains in the filter only for forward-compat.
  interactive_non_numeric_condition = "((search_type = \"interactive\" or search_type = \"internal\") and ${local.non_numeric_query_condition})"

  # Empty-result numerators for those cohorts (definitions differ by search type).
  # classic_empty_commodity_only is only safe after classic_non_numeric_fuzzy_condition
  # (exact matches already excluded by that cohort filter).
  classic_empty_commodity_only = "((ispresent(commodity_result_count) and commodity_result_count = 0) or (not ispresent(commodity_result_count) and result_count = 0))"
  interactive_no_results_only  = "(result_count = 0)"

  # Verified Insights comparisons are numeric 1 and 0. Bare true/false are not used.
  # The nested sentinel expression failed to parse, so it is not used.
  # Missing flags are detected with ispresent. A present value other than 0 or 1 is also unknown.
  suspicious_one         = "(suspicious = 1)"
  suspicious_zero        = "(ispresent(suspicious) and suspicious = 0)"
  duplicate_one          = "(duplicate = 1)"
  duplicate_zero         = "(ispresent(duplicate) and duplicate = 0)"
  allowed_one            = "(ispresent(allowed) and allowed = 1)"
  allowed_zero           = "(ispresent(allowed) and allowed = 0)"
  matched_one            = "(matched = 1)"
  matched_zero           = "(ispresent(matched) and matched = 0)"
  unknown_flag_condition = "(not ispresent(suspicious) or not ispresent(duplicate) or not ispresent(allowed) or (ispresent(suspicious) and not (suspicious = 1 or suspicious = 0)) or (ispresent(duplicate) and not (duplicate = 1 or duplicate = 0)) or (ispresent(allowed) and not (allowed = 1 or allowed = 0)))"

  # Named outcomes require present numeric flags. guard_disabled is a reason, not a field.
  # A missing reason is not validator clearance.
  guard_outcome_category = "case(${local.suspicious_zero} and ${local.duplicate_zero} and ${local.allowed_one} and reason = \"guard_disabled\", \"Disabled\", ${local.suspicious_zero} and ${local.duplicate_zero} and ${local.allowed_one} and reason = \"not_suspicious\", \"Not suspicious\", ${local.suspicious_one} and ${local.duplicate_zero} and ${local.allowed_one} and reason = \"validator_unparseable\", \"Validator unavailable/unparseable, allowed\", ${local.suspicious_one} and ${local.duplicate_zero} and ${local.allowed_one} and ispresent(reason) and reason != \"\" and reason != \"validator_unparseable\" and reason != \"guard_disabled\" and reason != \"not_suspicious\", \"Suspicious, allowed without fail-open marker\", ${local.suspicious_one} and ${local.duplicate_one} and ${local.allowed_zero} and (not ispresent(reason) or (reason != \"guard_disabled\" and reason != \"not_suspicious\" and reason != \"validator_unparseable\")), \"Duplicate blocked\", \"Unknown/inconsistent\")"

  defined_empty_search_types = "(search_type = \"classic\" or search_type = \"interactive\" or search_type = \"internal\")"

  search_dashboard_url            = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_quality" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode(local.dashboard_body)
}

locals {
  dashboard_body = {
    periodOverride = "inherit"
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 4
        properties = {
          markdown = join("\n", [
            "## Search Quality",
            "Search team: review empty results and selections. Counts are completed-search events, not journeys or people.",
            "Recorded empty events and completed searches versus selections use metrics (UK + XI). Other widgets use logs. History starts at metric collection; gaps are not zero.",
            "[Overview](${local.search_dashboard_url}) | [Operations](${local.search_operations_dashboard_url}) | [Definitions](https://github.com/trade-tariff/trade-tariff-backend/blob/main/docs/search-dashboards.md)",
          ])
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 4
        width  = 12
        height = 6
        properties = {
          title  = "Interactive completed events by response type"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
            | fields case(ispresent(final_result_type) and final_result_type != "", final_result_type, "Unspecified / not applicable") as response_type
            | stats count(*) as completion_events by response_type
            | sort completion_events desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 4
        width  = 12
        height = 6
        properties = {
          title  = "Completed events by results type, all search types"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed"
            | fields search_type, case(ispresent(results_type) and results_type != "", results_type, "Missing results type") as results_type_label
            | stats count(*) as completion_events by search_type, results_type_label
            | sort completion_events desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 10
        width  = 24
        height = 6
        properties = {
          title  = "Hourly mean and median results per completed event"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed"
            | stats avg(result_count) as hourly_mean_results, median(result_count) as hourly_median_results, avg(commodity_result_count) as hourly_mean_commodity_results, count(*) as completion_events, sum(if(ispresent(result_count), 1, 0)) as events_with_result_count, sum(if(ispresent(commodity_result_count), 1, 0)) as events_with_commodity_count by search_type, bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 16
        width  = 12
        height = 6
        properties = {
          title  = "Classic completed events by outcome"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "classic"
            | fields case(results_type = "exact_search", "Exact match", ispresent(commodity_result_count) and commodity_result_count > 0, "Commodity hits", ispresent(commodity_result_count) and commodity_result_count = 0 and result_count > 0, "Other hits only", result_count = 0, "No results", not ispresent(commodity_result_count) and result_count > 0, "Incomplete level breakdown", "Other") as classic_outcome
            | stats count(*) as completion_events by classic_outcome
            | sort completion_events desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 16
        width  = 12
        height = 6
        properties = {
          title  = "Classic empty events: no results versus other hits only"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.classic_empty_commodity_condition}
            | fields case(result_count = 0, "No results", ispresent(commodity_result_count) and commodity_result_count = 0 and result_count > 0, "Other hits only", "Unclassifiable empty") as empty_kind
            | stats count(*) as empty_events by empty_kind
            | sort empty_events desc
          EOT
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 22
        width  = 12
        height = 6
        properties = {
          title                = "Recorded empty events by search type, UK + XI"
          region               = var.region
          view                 = "bar"
          stat                 = "Sum"
          setPeriodToTimeRange = true
          yAxis                = { left = { label = "Empty events", showUnits = false, min = 0 } }
          metrics = concat(
            [for search_type in ["classic", "interactive", "internal"] : [local.namespace, "EmptyResults", "Environment", var.environment, "Service", "uk", "SearchType", search_type, { id = "empty_${search_type}_uk", visible = false }]],
            [for search_type in ["classic", "interactive", "internal"] : [local.namespace, "EmptyResults", "Environment", var.environment, "Service", "xi", "SearchType", search_type, { id = "empty_${search_type}_xi", visible = false }]],
            [for search_type in ["classic", "interactive", "internal"] : [{
              id         = "empty_${search_type}"
              label      = search_type
              expression = "IF(empty_${search_type}_uk + empty_${search_type}_xi > 0, empty_${search_type}_uk + empty_${search_type}_xi)"
            }]]
          )
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 22
        width  = 12
        height = 6
        properties = {
          title  = "Classic empty events, % of all completions, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Percent of classic completions", showUnits = false, min = 0, max = 100 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "classic"
            | stats sum(if(${local.classic_empty_commodity_condition}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct, sum(if(${local.classic_no_results_condition}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 28
        width  = 24
        height = 6
        properties = {
          title  = "Top 30 empty queries, including code lookups"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.zero_result_condition}
            | fields case(not ispresent(query), "Missing query", query like /^[ \t\r\n]*$/, "Blank or whitespace query", query) as query_text, search_type
            | stats count(*) as empty_events by query_text, search_type
            | sort empty_events desc
            | limit 30
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 34
        width  = 24
        height = 8
        properties = {
          title  = "Latest 30 empty events"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.zero_result_condition}
            | fields @timestamp, search_type, results_type, result_count, commodity_result_count, query, request_source, request_id, chapter_result_count, heading_result_count, other_result_count
            | sort @timestamp desc
            | limit 30
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 42
        width  = 12
        height = 6
        properties = {
          title  = "Hourly mean results per completed classic search, by level"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Mean results per completed event", showUnits = false, min = 0 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "classic"
            | stats avg(chapter_result_count) as hourly_mean_chapters, avg(heading_result_count) as hourly_mean_headings, avg(commodity_result_count) as hourly_mean_commodities, avg(other_result_count) as hourly_mean_other, avg(result_count) as hourly_mean_total by bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 42
        width  = 12
        height = 6
        properties = {
          title  = "Classic free-text non-exact empty commodity %, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Percent of free-text non-exact completions", showUnits = false, min = 0, max = 100 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.classic_non_numeric_fuzzy_condition}
            | stats sum(if(${local.classic_empty_commodity_only}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct by bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 48
        width  = 12
        height = 6
        properties = {
          title  = "Guided free-text no-results %, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Percent of guided free-text completions", showUnits = false, min = 0, max = 100 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.interactive_non_numeric_condition}
            | stats sum(if(${local.interactive_no_results_only}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 48
        width  = 12
        height = 6
        properties = {
          title  = "Empty events, % of classic, interactive and internal completions, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Percent of completions", showUnits = false, min = 0, max = 100 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and ${local.defined_empty_search_types}
            | stats sum(if(${local.zero_result_condition}, 1, 0)) * 100.0 / count(*) as empty_result_rate_pct by search_type, bin(1h)
          EOT
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 54
        width  = 12
        height = 6
        properties = {
          title  = "Completed searches and selections per hour, UK + XI"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 3600
          yAxis  = { left = { label = "Events per hour", showUnits = false, min = 0 } }
          metrics = concat(
            [for service in ["uk", "xi"] : [local.namespace, "SearchEvents", "Environment", var.environment, "Service", service, "Outcome", "completed", { id = "completed_${service}", visible = false }]],
            [for service in ["uk", "xi"] : [local.namespace, "ResultSelections", "Environment", var.environment, "Service", service, { id = "selected_${service}", visible = false }]],
            [
              [{ id = "completed", label = "search_completed", expression = "IF(completed_uk + completed_xi > 0, completed_uk + completed_xi)" }],
              [{ id = "selected", label = "result_selected", expression = "IF(selected_uk + selected_xi > 0, selected_uk + selected_xi)" }],
            ]
          )
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 54
        width  = 12
        height = 6
        properties = {
          title  = "Selected result types, event counts"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "result_selected"
            | fields case(ispresent(goods_nomenclature_class) and goods_nomenclature_class != "", goods_nomenclature_class, "Missing class") as selected_type
            | stats count(*) as selection_events by selected_type
            | sort selection_events desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 60
        width  = 24
        height = 6
        properties = {
          title  = "Top 20 selected identifiers"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "result_selected"
            | fields goods_nomenclature_item_id as code_or_route_id, case(ispresent(goods_nomenclature_class) and goods_nomenclature_class != "", goods_nomenclature_class, "Missing class") as selected_type
            | stats count(*) as selection_events by code_or_route_id, selected_type
            | sort selection_events desc
            | limit 20
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 66
        width  = 12
        height = 6
        properties = {
          title  = "Intercept checks by match result, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Checks per hour", showUnits = false, min = 0 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "description_intercept_checked"
            | fields case(${local.matched_one}, "Matched", ${local.matched_zero}, "Not matched", "Unknown") as match_result
            | stats count(*) as checks_per_hour by match_result, bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 66
        width  = 12
        height = 6
        properties = {
          title  = "Search AI call events by response type, hourly"
          region = var.region
          view   = "timeSeries"
          yAxis  = { left = { label = "Call events per hour", showUnits = false, min = 0 } }
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "api_call_completed"
            | fields case(ispresent(response_type) and response_type != "", response_type, "Missing response type") as response_type_label
            | stats count(*) as call_events by response_type_label, bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 72
        width  = 24
        height = 6
        properties = {
          title  = "Matched intercept configurations"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "description_intercept_checked" and matched = 1
            | fields case(ispresent(excluded) and excluded = 1, "Excluded", ispresent(excluded) and excluded = 0, "Not excluded", "Unknown") as excluded_configuration, case(ispresent(filtering) and filtering = 1, "Filtering", ispresent(filtering) and filtering = 0, "Not filtering", "Unknown") as filtering_configuration, case(not ispresent(guidance_level) or guidance_level = "", "Not configured", guidance_level) as guidance_level_label, case(not ispresent(guidance_location) or guidance_location = "", "Not configured", guidance_location) as guidance_location_label, case(ispresent(escalate_to_webchat) and escalate_to_webchat = 1, "Escalate configured", ispresent(escalate_to_webchat) and escalate_to_webchat = 0, "Escalate not configured", "Unknown") as webchat_configuration
            | stats count(*) as matched_checks by excluded_configuration, filtering_configuration, guidance_level_label, guidance_location_label, webchat_configuration
            | sort matched_checks desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 78
        width  = 24
        height = 6
        properties = {
          title  = "Top 30 intercept term/configuration combinations"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "description_intercept_checked" and matched = 1
            | stats count(*) as matched_checks by term, excluded, filtering, guidance_level, guidance_location, escalate_to_webchat
            | sort matched_checks desc
            | limit 30
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 84
        width  = 12
        height = 6
        properties = {
          title  = "Guided round number at request completion"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
            | fields case(ispresent(total_attempts), total_attempts, "Not recorded / not applicable") as guided_round_number
            | stats count(*) as completion_events by guided_round_number
            | sort guided_round_number asc
          EOT
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 84
        width  = 12
        height = 6
        properties = {
          title  = "Submitted answer-history entries at request completion"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
            | fields case(ispresent(total_questions), total_questions, "Not recorded / not applicable") as submitted_answer_history_entries
            | stats count(*) as completion_events by submitted_answer_history_entries
            | sort submitted_answer_history_entries asc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 90
        width  = 24
        height = 6
        properties = {
          title  = "Guard checks by mutually exclusive outcome"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "duplicate_question_guard_checked"
            | fields ${local.guard_outcome_category} as guard_outcome
            | stats count(*) as guard_check_events by guard_outcome
            | sort guard_check_events desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 96
        width  = 24
        height = 6
        properties = {
          title  = "Guard checks per hour, all-check denominator"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "duplicate_question_guard_checked"
            | stats count(*) as all_guard_check_events, sum(if(suspicious = 1, 1, 0)) as suspicious_events, sum(if(duplicate = 1, 1, 0)) as duplicate_events, sum(if(${local.suspicious_zero} and ${local.duplicate_zero} and ${local.allowed_one} and reason = "guard_disabled", 1, 0)) as disabled_events, sum(if(${local.unknown_flag_condition}, 1, 0)) as unknown_flag_events, round(100 * sum(if(suspicious = 1, 1, 0)) / count(*), 2) as suspicious_pct_of_all_checks, round(100 * sum(if(duplicate = 1, 1, 0)) / count(*), 2) as duplicate_pct_of_all_checks by bin(1h)
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 102
        width  = 24
        height = 6
        properties = {
          title  = "Suspicious guard checks by signal, overlapping categories"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "duplicate_question_guard_checked" and suspicious = 1
            | fields jsonParse(@message) as guard
            | unnest guard.signals into signal
            | stats count(*) as checks_carrying_signal by signal
            | sort checks_carrying_signal desc
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 108
        width  = 24
        height = 8
        properties = {
          title  = "Latest 30 guard decisions"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "duplicate_question_guard_checked"
            | fields jsonParse(@message) as guard
            | fields @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, jsonStringify(guard.signals) as signal_list, reason, reason_truncated, duplicate_of_question, duplicate_of_answer
            | display @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, signal_list, reason, reason_truncated, duplicate_of_question, duplicate_of_answer
            | sort @timestamp desc
            | limit 30
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 116
        width  = 24
        height = 8
        properties = {
          title  = "Latest 30 matched intercept checks"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "description_intercept_checked" and matched = 1
            | fields @timestamp, term, excluded, filtering, guidance_level, guidance_location, escalate_to_webchat, request_id, filter_prefix_count, query
            | sort @timestamp desc
            | limit 30
          EOT
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 124
        width  = 24
        height = 6
        properties = {
          title  = "Field presence by search type and free-text cohort, hourly"
          region = var.region
          view   = "table"
          query  = <<-EOT
            ${local.source}
            | ${local.service_filter} and event = "search_completed"
            | fields search_type, coalesce(case(not ispresent(query), "Missing query", ${local.non_numeric_query_condition}, "in free-text cohort", "outside free-text cohort"), "Unknown") as free_text_cohort
            | stats count(*) as completion_events, sum(if(ispresent(result_count), 1, 0)) as events_with_result_count, sum(if(ispresent(commodity_result_count), 1, 0)) as events_with_commodity_count, sum(if(search_type = "classic" and ispresent(result_count) and ispresent(chapter_result_count) and ispresent(heading_result_count) and ispresent(commodity_result_count) and ispresent(other_result_count), 1, 0)) as events_with_complete_classic_level_breakdown by search_type, free_text_cohort, bin(1h)
          EOT
        }
      },
    ]
  }
}
