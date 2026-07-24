locals {
  dashboard_name    = var.dashboard_name != null ? var.dashboard_name : "SearchExperiment-${var.environment}"
  source            = "SOURCE '${var.log_group_name}'"
  experiment_filter = "filter experiment = \"EXPERIMENT_LABEL\""
  search_filter     = "${local.experiment_filter} and service = \"search\""
  ai_cost_filter    = "filter event in [\"api_call_completed\", \"embedding_api_call_completed\"]\n              | ${local.experiment_filter} and ((service = \"search\" and event = \"api_call_completed\") or (service = \"ai_usage\" and event = \"embedding_api_call_completed\" and event_kind = \"vector_search_query_embedding\"))"

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
                  sum(if(event = "search_completed" and result_count = 0, 1, 0)) as zero_result_requests,
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
            title  = "E2E Latency (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | stats pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90, pct(total_duration_ms, 99) as p99 by search_type, bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 8
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
          y      = 8
          width  = 12
          height = 6
          properties = {
            title  = "AI Token Totals by Operation"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_filter}
              | fields if(ispresent(operation), operation, event_kind) as ai_operation
              | stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(total_tokens) as total_tokens by ai_operation, model
              | sort total_tokens desc
            EOT
          }
        },
        {
          type   = "log"
          x      = 0
          y      = 14
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
          y      = 14
          width  = 16
          height = 6
          properties = {
            title  = "AI API Latency (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by operation, bin(1h)
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
            title  = "Final Result Types"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | stats count(*) as searches by final_result_type
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
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Result Counts"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed"
              | stats avg(result_count) as average, median(result_count) as median, sum(if(result_count = 0, 1, 0)) as zero_results by search_type, bin(1h)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 26
          width  = 12
          height = 6
          properties = {
            title  = "Top Search Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_started"
              | stats count(*) as searches by query, search_type
              | sort searches desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 26
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
          y      = 32
          width  = 24
          height = 6
          properties = {
            title  = "Questions and Answers"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event in ["question_returned", "answer_returned"]
              | fields details.questions.0.question as question,
                  details.answers.0.commodity_code as top_commodity_code,
                  details.answers.0.confidence as top_confidence,
                  answer_count,
                  event,
                  effective_query,
                  request_id,
                  @timestamp
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
          y      = 38
          width  = 12
          height = 6
          properties = {
            title  = "Top Zero-Result Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.search_filter} and event = "search_completed" and result_count = 0
              | stats count(*) as searches by query, search_type
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
          y      = 44
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
