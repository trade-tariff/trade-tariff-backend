locals {
  dashboard_name         = var.dashboard_name != null ? var.dashboard_name : "SearchSample-${var.environment}"
  source                 = "SOURCE '${var.log_group_name}'"
  frontend_search_filter = "filter request_source = \"frontend\" and service = \"search\""
  cohort_field           = "fields case(experiment = \"tenpct\", \"tenpct\", experiment = \"trstd-trdr\" or experiment = \"demo\" or experiment = \"hmrc-users\", \"enrolled\", not ispresent(experiment) or experiment = \"\", \"control\", \"other\") as cohort"
  compare_filter         = "filter cohort = \"tenpct\" or cohort = \"control\""
  request_id_filter      = "filter ispresent(request_id) and request_id != \"\""
  ai_cost_events         = "filter event in [\"api_call_completed\", \"embedding_api_call_completed\", \"embedding_api_call_failed\"]\n              | filter ((service = \"search\" and event = \"api_call_completed\") or (service = \"ai_usage\" and event in [\"embedding_api_call_completed\", \"embedding_api_call_failed\"] and event_kind = \"vector_search_query_embedding\"))"
  # Classic empty commodity results: fuzzy/null with zero commodity hits (empty Best commodity matches).
  # Includes completely empty results and headings/chapters-only; excludes exact matches.
  # Interactive empty results: result_count = 0 (filter also accepts search_type=internal for forward-compat).
  # Historical classic falls back to result_count = 0.
  # Keep in sync with SearchAnalytics::CloudwatchSnapshotQuery#zero_result_condition
  # and the other search_*_dashboard modules.
  classic_empty_commodity_condition = "(search_type = \"classic\" and ((ispresent(commodity_result_count) and commodity_result_count = 0 and (not ispresent(results_type) or results_type != \"exact_search\")) or (not ispresent(commodity_result_count) and result_count = 0)))"
  interactive_no_results_condition  = "((search_type = \"interactive\" or search_type = \"internal\") and result_count = 0)"
  zero_result_condition             = "(${local.classic_empty_commodity_condition} or ${local.interactive_no_results_condition})"

  search_dashboard_url            = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
  search_experiment_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchExperiment-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_sample" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode(local.dashboard_body)
}

locals {
  dashboard_body = {
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 4
          properties = {
            markdown = join("\n", [
              "## Trade Tariff Search Sample",
              "Compares Flagsmith-offered frontend search (`experiment = tenpct`) with unlabelled frontend search (control). URL enrolments (`trstd-trdr`, `demo`, `hmrc-users`) are coverage only; they stay on Search Experiment.",
              "**Sample is not “used guided search”.** People in `tenpct` can still run classic. Interactive volume inside sample is use of beta. Control is not a clean 90%: it includes traffic from before the stamp, Flagsmith fallbacks, and browsers that never received a label. Distinct session counts are estimated, not people, and are not additive across hours.",
              "**Counting:** search widgets collapse to one row per `request_id` before totals and rates. Missing request IDs are dropped from those charts, not treated as zero. Empty-result and selection rates use completed searches in that cohort and type. Refresh is manual; each widget starts a new Logs Insights scan. Use a window that starts after the `tenpct` stamp shipped.",
              "**Empty commodity results (classic):** fuzzy/null with zero commodity hits (empty Best commodity matches). **Empty results (interactive):** no returned results.",
              "**Start here:** check label coverage, then volume by cohort and type, then empty-result and selection rates. Open Search Experiment for trusted-trader URLs.",
              "**Related:** [Search Overview](${local.search_dashboard_url}) | [Search Operations](${local.search_operations_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url}) | [Search Experiments](${local.search_experiment_dashboard_url})",
            ])
          }
        }
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 4
          width  = 12
          height = 6
          properties = {
            title  = "Frontend Search Label Coverage"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event = "search_completed"
              | ${local.cohort_field}
              | ${local.request_id_filter}
              | stats earliest(@timestamp) as requested_at by request_id, cohort
              | stats count(*) as completed_requests by cohort
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
            title  = "Completed Searches by Cohort"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event in ["search_completed", "search_failed"]
              | ${local.cohort_field}
              | ${local.compare_filter}
              | ${local.request_id_filter}
              | stats max(if(event = "search_completed", 1, 0)) as completed,
                  max(if(event = "search_failed", 1, 0)) as failed,
                  latest(search_type) as search_type by request_id, cohort
              | stats sum(completed) as completed_requests, sum(failed) as failed_requests,
                  sum(if(completed = 1 and (search_type = "interactive" or search_type = "internal"), 1, 0)) as interactive_completed,
                  sum(if(completed = 1 and search_type = "classic", 1, 0)) as classic_completed by cohort
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 10
          width  = 24
          height = 6
          properties = {
            title  = "Completed Searches by Cohort and Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event = "search_completed"
              | ${local.cohort_field}
              | ${local.compare_filter}
              | ${local.request_id_filter}
              | stats earliest(@timestamp) as requested_at, latest(search_type) as search_type by request_id, cohort
              | stats count(*) as completed_searches by cohort, search_type, datefloor(requested_at, 1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 16
          width  = 12
          height = 6
          properties = {
            title  = "Empty Result Rate by Cohort and Type"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event = "search_completed"
              | ${local.cohort_field}
              | ${local.compare_filter}
              | ${local.request_id_filter}
              | stats earliest(@timestamp) as requested_at, latest(search_type) as search_type,
                  max(if(${local.zero_result_condition}, 1, 0)) as empty_result by request_id, cohort
              | stats sum(empty_result) as empty_results, count(*) as completed_searches by cohort, search_type
              | filter completed_searches > 0
              | fields empty_results * 100.0 / completed_searches as empty_result_rate_percent
              | display cohort, search_type, empty_results, completed_searches, empty_result_rate_percent
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
            title  = "Selection Rate by Cohort"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event in ["search_completed", "result_selected"]
              | ${local.cohort_field}
              | ${local.compare_filter}
              | ${local.request_id_filter}
              | stats max(if(event = "result_selected", 1, 0)) as selected,
                  max(if(event = "search_completed" and result_count > 0, 1, 0)) as selectable by request_id, cohort
              | filter selectable = 1
              | stats sum(selected) as selected_requests, count(*) as selectable_requests by cohort
              | fields selected_requests * 100.0 / selectable_requests as selection_rate_percent
              | display cohort, selected_requests, selectable_requests, selection_rate_percent
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 22
          width  = 12
          height = 6
          properties = {
            title  = "E2E Latency in seconds (p50/p90) by Cohort"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event = "search_completed"
              | ${local.cohort_field}
              | ${local.compare_filter}
              | filter ispresent(total_duration_ms)
              | stats pct(total_duration_ms / 1000, 50) as p50_seconds, pct(total_duration_ms / 1000, 90) as p90_seconds by cohort, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 22
          width  = 12
          height = 6
          properties = {
            title  = "Priced AI Cost by Cohort"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_events}
              | filter request_source = "frontend"
              | ${local.cohort_field}
              | ${local.compare_filter}
              | filter pricing_known
              | filter ispresent(total_cost_usd)
              | stats sum(total_cost_usd) as total_cost_usd, count(*) as priced_calls by cohort
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 28
          width  = 8
          height = 6
          properties = {
            title  = "Questions per Interactive Search"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event = "search_completed" and (search_type = "interactive" or search_type = "internal")
              | ${local.cohort_field}
              | ${local.compare_filter}
              | ${local.request_id_filter}
              | filter ispresent(total_questions)
              | stats latest(total_questions) as questions by request_id, cohort
              | stats avg(questions) as avg_questions, pct(questions, 50) as p50_questions, count(*) as interactive_searches by cohort
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 28
          width  = 8
          height = 6
          properties = {
            title  = "I Don't Know Usage in Sample"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | filter experiment = "tenpct" and event = "guided_search.journey" and schema_version = 1 and outcome in ["page_visible", "dont_know"]
              | fields case(outcome = "dont_know", request_id) as dont_know_request_id,
                  case(outcome = "dont_know" or (outcome = "page_visible" and destination = "question"), request_id) as question_request_id
              | stats sum(if(outcome = "dont_know", 1, 0)) as dont_know_uses,
                  count_distinct(dont_know_request_id) as requests_using_dont_know,
                  count_distinct(question_request_id) as requests_shown_questions
              | filter requests_shown_questions > 0
              | fields requests_using_dont_know * 100.0 / requests_shown_questions as request_usage_rate_percent
              | display dont_know_uses, requests_using_dont_know, requests_shown_questions, request_usage_rate_percent
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 28
          width  = 8
          height = 6
          properties = {
            title  = "Estimated Sample Browser Sessions"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | filter experiment = "tenpct" and event = "guided_search.journey" and schema_version = 1
              | filter browser_session_id like /^v1:[0-9a-f]{64}$/
              | stats count_distinct(browser_session_id) as estimated_browser_sessions
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 34
          width  = 24
          height = 6
          properties = {
            title  = "Recent Sample and Control Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.frontend_search_filter} and event in ["search_completed", "search_failed"]
              | ${local.cohort_field}
              | ${local.compare_filter}
              | fields @timestamp, request_id, cohort, search_type, event
              | sort @timestamp desc
              | limit 20
            EOT
          }
        },
      ],
    )
  }
}
