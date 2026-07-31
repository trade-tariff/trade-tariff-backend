locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SearchQuality-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""

  # Classic product-quality empty commodities: fuzzy/null searches with commodity_result_count = 0.
  # That is "Best commodity matches" empty — includes both:
  #   - completely empty results (result_count = 0)
  #   - headings/chapters/other hits only (result_count > 0, commodity_result_count = 0)
  # Exact matches are never product zeros, even when commodity_result_count is 0.
  # Historical classic logs without commodity_result_count fall back to result_count = 0.
  classic_empty_commodity_condition = "(search_type = \"classic\" and ((ispresent(commodity_result_count) and commodity_result_count = 0 and (not ispresent(results_type) or results_type != \"exact_search\")) or (not ispresent(commodity_result_count) and result_count = 0)))"

  # Classic completely empty bag (subset of empty commodities when the new field is present).
  classic_no_results_condition = "(search_type = \"classic\" and result_count = 0)"

  # Interactive/internal empty: no returned results at all.
  interactive_no_results_condition = "((search_type = \"interactive\" or search_type = \"internal\") and result_count = 0)"

  # Shared rate/term widgets: classic uses empty-commodity product metric; interactive uses no results.
  # Keep in sync with SearchAnalytics::CloudwatchSnapshotQuery#zero_result_condition
  # and the other search_*_dashboard modules.
  zero_result_condition = "(${local.classic_empty_commodity_condition} or ${local.interactive_no_results_condition})"

  # Free-text queries only (same regex as admin search_term_improvements analytics).
  # Digits, spaces, dots, and hyphens alone count as numeric/code lookups.
  non_numeric_query_condition = "(ispresent(query) and query not like /^[0-9 .-]+$/)"

  # Classic free-text fuzzy/null cohort (excludes exact code matches).
  classic_non_numeric_fuzzy_condition = "(search_type = \"classic\" and ${local.non_numeric_query_condition} and (not ispresent(results_type) or results_type != \"exact_search\"))"

  # Guided free-text cohort. Api::Internal::SearchService and InteractiveSearchService
  # both emit search_type = "interactive" today; keep "internal" for forward-compat with
  # analytics views that treat interactive|internal as the guided path.
  interactive_non_numeric_condition = "((search_type = \"interactive\" or search_type = \"internal\") and ${local.non_numeric_query_condition})"

  # Product-zero numerators for those cohorts (definitions differ by search type).
  # classic_empty_commodity_only is only safe after classic_non_numeric_fuzzy_condition
  # (exact matches already excluded by that cohort filter).
  classic_empty_commodity_only = "((ispresent(commodity_result_count) and commodity_result_count = 0) or (not ispresent(commodity_result_count) and result_count = 0))"
  interactive_no_results_only  = "(result_count = 0)"

  search_dashboard_url            = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_quality" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = join("\n", [
              "## Trade Tariff Search Quality",
              "Behaviour and product-quality dashboard for search outcomes, empty-result terms, intercepts, and result selection patterns across **classic** and **interactive/internal** search.",
              "**Classic product zero:** fuzzy/null with zero commodity hits (`commodity_result_count = 0`) — empty “Best commodity matches”. Exact matches are not zeros.",
              "**Classic empty kinds (pie):** split into **no results** (`result_count = 0`) vs **no commodities, other hits** (headings/chapters/sections only).",
              "**Interactive/internal zero:** no returned results (`result_count = 0`). Counted separately from classic commodity empties.",
              "**Non-numeric free-text rates:** free-text only (`query not like /^[0-9 .-]+$/`). Classic = empty commodity % of non-exact free-text; interactive/internal = empty result % of free-text guided search (logs use `search_type=interactive`).",
              "**Healthy:** empty-commodity terms stay stable, result types remain consistent, intercept matches track expected terms, and interactive outcomes do not skew towards errors.",
              "**Start here:** classic outcome pies and empty-result widgets first, then intercept and selection drill-downs.",
              "**Related:** [Search Overview](${local.search_dashboard_url}) | [Search Operations](${local.search_operations_dashboard_url})",
            ])
          }
        }
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 2
          width  = 8
          height = 6
          properties = {
            title  = "Final Result Type (Interactive)"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by final_result_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 2
          width  = 8
          height = 6
          properties = {
            title  = "Results Type Breakdown"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by results_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 2
          width  = 8
          height = 6
          properties = {
            title  = "Average Result Count by Search Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats avg(result_count) as avg_results, median(result_count) as median_results, avg(commodity_result_count) as avg_commodity_results by search_type, bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 8
          width  = 8
          height = 6
          properties = {
            title  = "Classic Search Outcomes"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "classic"
              | fields case(results_type = "exact_search", "exact match", ispresent(commodity_result_count) and commodity_result_count > 0, "has commodities", ispresent(commodity_result_count) and commodity_result_count = 0 and result_count > 0, "no commodities (other hits)", result_count = 0, "no results", "other") as classic_outcome
              | stats count(*) as searches by classic_outcome
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 8
          width  = 8
          height = 6
          properties = {
            title  = "Classic Empty Kinds"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.classic_empty_commodity_condition}
              | fields case(result_count = 0, "no results", ispresent(commodity_result_count) and commodity_result_count = 0 and result_count > 0, "no commodities (other hits)", "other empty") as empty_kind
              | stats count(*) as searches by empty_kind
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 8
          width  = 8
          height = 6
          properties = {
            title  = "Product Zeros by Search Type"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.zero_result_condition}
              | stats count(*) as searches by search_type
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Top 30 Product-Zero Search Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.zero_result_condition}
              | stats count(*) as searches by query, search_type
              | sort searches desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Recent Product-Zero Searches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.zero_result_condition}
              | fields @timestamp, query, request_source, search_type, request_id, results_type, result_count, chapter_result_count, heading_result_count, commodity_result_count, other_result_count
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Classic Empty Rates"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "classic"
              | stats sum(if(${local.classic_empty_commodity_condition}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct, sum(if(${local.classic_no_results_condition}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Classic Result Counts by Level"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "classic"
              | stats avg(chapter_result_count) as avg_chapters, avg(heading_result_count) as avg_headings, avg(commodity_result_count) as avg_commodities, avg(other_result_count) as avg_other, avg(result_count) as avg_total by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Classic Product-Zero Rate (non-numeric fuzzy)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.classic_non_numeric_fuzzy_condition}
              | stats sum(if(${local.classic_empty_commodity_only}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Interactive/Internal Product-Zero Rate (non-numeric)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and ${local.interactive_non_numeric_condition}
              | stats sum(if(${local.interactive_no_results_only}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 26
          width  = 24
          height = 6
          properties = {
            title  = "Product-Zero Rate (all queries by search type)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats sum(if(${local.zero_result_condition}, 1, 0)) * 100.0 / count(*) as product_zero_rate_pct by search_type, bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 32
          width  = 8
          height = 6
          properties = {
            title  = "Searches vs Selections"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_completed", "result_selected"]
              | stats count(*) as count by event, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 32
          width  = 8
          height = 6
          properties = {
            title  = "Selected Result Types"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "result_selected"
              | stats count(*) as selections by goods_nomenclature_class
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 32
          width  = 8
          height = 6
          properties = {
            title  = "Top Selected Codes"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "result_selected"
              | stats count(*) as selections by goods_nomenclature_item_id, goods_nomenclature_class
              | sort selections desc
              | limit 20
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 38
          width  = 8
          height = 6
          properties = {
            title  = "Intercept Checks Over Time"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked"
              | stats count(*) as checks by matched, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 38
          width  = 8
          height = 6
          properties = {
            title  = "Intercept Outcomes"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | stats count(*) as matches by excluded, filtering, guidance_level, guidance_location, escalate_to_webchat
              | sort matches desc
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 38
          width  = 8
          height = 6
          properties = {
            title  = "Top Matched Intercept Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | stats count(*) as matches by term, excluded, filtering, guidance_level, guidance_location, escalate_to_webchat
              | sort matches desc
              | limit 30
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 44
          width  = 12
          height = 6
          properties = {
            title  = "AI Response Types Over Time"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats count(*) as calls by response_type, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 44
          width  = 6
          height = 6
          properties = {
            title  = "Attempts Per Search"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_attempts
              | sort total_attempts asc
            EOT
          }
        },
        {
          type   = "log"
          x      = 18
          y      = 44
          width  = 6
          height = 6
          properties = {
            title  = "Questions Per Search"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_questions
              | sort total_questions asc
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 50
          width  = 8
          height = 6
          properties = {
            title  = "Duplicate Guard Outcomes"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "duplicate_question_guard_checked"
              | stats count(*) as checks by suspicious, duplicate, allowed
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 50
          width  = 8
          height = 6
          properties = {
            title  = "Duplicate Guard Rates"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "duplicate_question_guard_checked"
              | stats count(*) as checks,
                  sum(if(suspicious = true, 1, 0)) as suspicious_checks,
                  sum(if(duplicate = true, 1, 0)) as duplicate_checks,
                  round(100 * sum(if(suspicious = true, 1, 0)) / count(*), 2) as suspicious_pct,
                  round(100 * sum(if(duplicate = true, 1, 0)) / count(*), 2) as duplicate_pct
                by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 50
          width  = 8
          height = 6
          properties = {
            title  = "Duplicate Guard Signal Breakdown"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "duplicate_question_guard_checked" and suspicious = true
              | fields jsonParse(@message) as guard
              | unnest guard.signals into signal
              | stats count(*) as checks by signal
              | sort checks desc
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 56
          width  = 24
          height = 6
          properties = {
            title  = "Recent Duplicate Guard Decisions"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "duplicate_question_guard_checked"
              | fields @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, signals, reason, duplicate_of_question, duplicate_of_answer
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 62
          width  = 24
          height = 6
          properties = {
            title  = "Recent Intercept Matches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | fields @timestamp, query, term, excluded, filtering, filter_prefix_count, guidance_level, guidance_location, escalate_to_webchat, request_id
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
      ]
    )
  })
}
