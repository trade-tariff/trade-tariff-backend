locals {
  dashboard_name    = var.dashboard_name != null ? var.dashboard_name : "SearchExperiment-${var.environment}"
  source            = "SOURCE '${var.log_group_name}'"
  experiment_filter = "filter experiment = \"EXPERIMENT_LABEL\""
  search_filter     = "${local.experiment_filter} and service = \"search\""
  ai_cost_filter    = "filter event in [\"api_call_completed\", \"embedding_api_call_completed\"]\n              | ${local.experiment_filter} and ((service = \"search\" and event = \"api_call_completed\") or (service = \"ai_usage\" and event = \"embedding_api_call_completed\" and event_kind = \"vector_search_query_embedding\"))"
  # Classic empty commodity results: fuzzy/null with commodity_result_count = 0 (empty Best commodity matches).
  # Includes completely empty results and headings/chapters-only; excludes exact matches.
  # Interactive/internal empty results: result_count = 0. Historical classic falls back to result_count = 0.
  # Keep in sync with SearchAnalytics::CloudwatchSnapshotQuery#zero_result_condition
  # and the other search_*_dashboard modules.
  classic_empty_commodity_condition = "(search_type = \"classic\" and ((ispresent(commodity_result_count) and commodity_result_count = 0 and (not ispresent(results_type) or results_type != \"exact_search\")) or (not ispresent(commodity_result_count) and result_count = 0)))"
  interactive_no_results_condition  = "((search_type = \"interactive\" or search_type = \"internal\") and result_count = 0)"
  zero_result_condition             = "(${local.classic_empty_commodity_condition} or ${local.interactive_no_results_condition})"

  search_dashboard_url            = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_experiment" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    variables = [
      {
        type         = "pattern"
        pattern      = "EXPERIMENT_LABEL"
        inputType    = "input"
        id           = "experiment"
        label        = "Experiment label"
        defaultValue = "trstd-trdr"
        visible      = true
      }
    ]
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
              "## Trade Tariff Search Production UAT",
              "All widgets are scoped to the experiment label selected above. Requests and estimated distinct guided-search browser sessions are reported separately. One browser session can contain multiple requests. CloudWatch may approximate high-cardinality counts.",
              "**Empty commodity results (classic):** fuzzy/null with zero commodity hits (empty Best commodity matches). **Empty results (interactive/internal):** no returned results. Shared widgets break series down by `search_type` where relevant.",
              "**Start here:** Set the dashboard time range to the UAT window, then review volume, reliability, latency, outcomes, questions, search terms, and costs.",
              "**Investigate:** copy the request ID into admin search diagnostics to reconstruct an individual request.",
              "**Related:** [Search Overview](${local.search_dashboard_url}) | [Search Operations](${local.search_operations_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url})",
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
            title  = "UAT Period Totals"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter}
              | fields case(event = "guided_search.journey" and schema_version = 1 and browser_session_id like /^v1:[0-9a-f]{64}$/, browser_session_id) as guided_search_browser_session_id
              | filter (service = "search" and event in ["search_completed", "search_failed"])
                  or ispresent(guided_search_browser_session_id)
              | stats count_distinct(guided_search_browser_session_id) as estimated_browser_sessions,
                  sum(if(event = "search_completed", 1, 0)) as completed_requests,
                  sum(if(event = "search_failed", 1, 0)) as hard_failures,
                  sum(if(event = "search_completed" and final_result_type = "error", 1, 0)) as error_outcomes,
                  sum(if(event = "search_completed" and ${local.zero_result_condition}, 1, 0)) as zero_result_requests,
                  sum(if(event = "guided_search.journey" and outcome = "result_selected", 1, 0)) as selections
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
            title  = "Hourly Request Volume"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event in ["search_completed", "search_failed"]
              | stats sum(if(event = "search_completed", 1, 0)) as completed_requests,
                  sum(if(event = "search_failed", 1, 0)) as failed_requests by search_type, bin(1h)
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
            title  = "E2E Latency in seconds (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | stats pct(total_duration_ms / 1000, 50) as p50_seconds, pct(total_duration_ms / 1000, 90) as p90_seconds, pct(total_duration_ms / 1000, 99) as p99_seconds by bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 8
          width  = 6
          height = 6
          properties = {
            title  = "Estimated Unique Browser Sessions"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1
              | filter browser_session_id like /^v1:[0-9a-f]{64}$/
              | stats count_distinct(browser_session_id) as estimated_browser_sessions
            EOT
          }
        },
        {
          type   = "log"
          x      = 6
          y      = 8
          width  = 10
          height = 6
          properties = {
            title  = "Guided Search Page Destinations"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1 and outcome = "page_visible"
              | filter browser_session_id like /^v1:[0-9a-f]{64}$/
              | stats count(*) as page_views, count_distinct(request_id) as distinct_requests,
                  count_distinct(browser_session_id) as estimated_browser_sessions by destination
              | sort page_views desc
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
            title  = "Guided Search Errors and Fallbacks"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter}
              | filter (event = "guided_search.journey" and schema_version = 1 and outcome in ["input_error", "backend_error", "no_results", "unknown_results", "blocking_guidance"])
                  or (service = "search" and event = "search_failed")
                  or (service = "search" and event = "search_completed" and final_result_type = "error")
              | fields if(event = "guided_search.journey", outcome, if(event = "search_failed", "search_failed", "error_result")) as error_or_fallback
              | stats count(*) as events, count_distinct(request_id) as distinct_requests by error_or_fallback
              | sort events desc
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
            title  = "I Don't Know Usage"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1 and outcome in ["page_visible", "dont_know"]
              | fields case(outcome = "dont_know", request_id) as dont_know_request_id,
                  case(outcome = "dont_know" or (outcome = "page_visible" and destination = "question"), request_id) as question_request_id
              | stats sum(if(outcome = "dont_know", 1, 0)) as dont_know_uses,
                  count_distinct(dont_know_request_id) as requests_using_dont_know,
                  count_distinct(question_request_id) as requests_shown_questions
              | filter requests_shown_questions > 0
              | fields requests_using_dont_know * 100 / requests_shown_questions as request_usage_rate_percent
              | display dont_know_uses, requests_using_dont_know, requests_shown_questions, request_usage_rate_percent
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
            title  = "Client Navigation Time in seconds by Destination (p50/p90/p99)"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1 and outcome = "page_visible"
              | filter ispresent(client_navigation_ms)
              | stats pct(client_navigation_ms / 1000, 50) as p50_seconds,
                  pct(client_navigation_ms / 1000, 90) as p90_seconds,
                  pct(client_navigation_ms / 1000, 99) as p99_seconds by destination
              | sort p90_seconds desc
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
            title  = "Question Response Time in seconds (p50/p90/p99)"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1
              | filter ispresent(client_elapsed_ms)
              | stats pct(client_elapsed_ms / 1000, 50) as p50_seconds,
                  pct(client_elapsed_ms / 1000, 90) as p90_seconds,
                  pct(client_elapsed_ms / 1000, 99) as p99_seconds
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "Total AI Cost by Operation"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_filter}
              | fields if(ispresent(operation), operation, event_kind) as ai_operation
              | filter pricing_known
              | filter ispresent(total_cost_usd)
              | stats sum(total_cost_usd) as total_cost_usd by ai_operation, model
              | sort total_cost_usd desc
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "AI Token Totals by Operation"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_filter}
              | fields if(ispresent(operation), operation, event_kind) as ai_operation
              | stats sum(input_tokens) as input_token_total, sum(output_tokens) as output_token_total, sum(total_tokens) as token_total by ai_operation, model
              | sort token_total desc
            EOT
          }
        },
        {
          type   = "log"
          x      = 0
          y      = 26
          width  = 8
          height = 6
          properties = {
            title  = "Unknown Pricing Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_filter}
              | fields if(ispresent(operation), operation, event_kind) as ai_operation
              | filter not pricing_known or not ispresent(total_cost_usd)
              | stats count(*) as events, sum(total_tokens) as total_tokens, sum(total_cost_usd) as partial_cost_usd by ai_operation, model
              | sort events desc, partial_cost_usd desc, total_tokens desc
              | limit 50
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 26
          width  = 16
          height = 6
          properties = {
            title  = "AI API Latency in seconds (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "api_call_completed"
              | stats pct(duration_ms / 1000, 50) as p50_seconds, pct(duration_ms / 1000, 90) as p90_seconds, pct(duration_ms / 1000, 99) as p99_seconds by bin(1h)
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
            title  = "Search Response Types"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | fields case(final_result_type = "answers", "suggested results", final_result_type = "questions", "questions", final_result_type = "error", "errors", ${local.zero_result_condition}, "no results", "results without questions") as search_response_type
              | stats count(*) as completed_searches by search_response_type
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
            title  = "Questions per Search"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_questions
              | sort total_questions asc
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
            title  = "Result Counts"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | stats avg(result_count) as average, median(result_count) as median, avg(commodity_result_count) as average_commodity, sum(if(${local.zero_result_condition}, 1, 0)) as zero_results by search_type, bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 38
          width  = 12
          height = 6
          properties = {
            title  = "Top Search Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_started"
              | stats count_distinct(request_id) as searches by query, search_type
              | sort searches desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 38
          width  = 12
          height = 6
          properties = {
            title  = "Errors"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter}
              | filter event = "search_failed" or final_result_type = "error" or response_type = "error"
              | fields @timestamp, request_id, event, search_type, operation, error_type, error_message
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
          y      = 44
          width  = 24
          height = 6
          properties = {
            title  = "Questions and Answer Options"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event in ["question_returned", "answer_returned"]
              | fields jsonParse(@message) as event_payload
              | fields event_payload.details.questions[0].question as question,
                  jsonStringify(event_payload.details.questions[0].options) as answer_options,
                  details.answers.0.commodity_code as top_commodity_code,
                  details.answers.0.confidence as top_confidence,
                  answer_count,
                  event,
                  effective_query,
                  request_id,
                  @timestamp
              | display @timestamp, request_id, event, effective_query, question, answer_options, top_commodity_code, top_confidence, answer_count
              | sort @timestamp desc
              | limit 50
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 50
          width  = 12
          height = 6
          properties = {
            title  = "Top Empty Commodity / Empty Result Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed" and ${local.zero_result_condition}
              | stats count(*) as searches by query, search_type
              | sort searches desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 50
          width  = 12
          height = 6
          properties = {
            title  = "Selected Results"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "guided_search.journey" and schema_version = 1 and outcome = "result_selected"
              | filter browser_session_id like /^v1:[0-9a-f]{64}$/
              | stats count(*) as selections by goods_nomenclature_item_id, confidence
              | sort selections desc
              | limit 30
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
          height = 8
          properties = {
            title  = "Recent UAT Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter}
              | fields @timestamp, request_id, service, event, schema_version, outcome, destination, result_rank, confidence, used_dont_know, client_elapsed_ms, client_navigation_ms, event_kind, search_type, query, effective_query, question_count, option_count, answer_count, total_questions, result_count, results_type, final_result_type, total_duration_ms, duration_ms, operation, model, total_tokens, total_cost_usd, error_message, details
              | sort @timestamp desc
              | limit 100
            EOT
          }
        },
      ]
    )
  })
}
