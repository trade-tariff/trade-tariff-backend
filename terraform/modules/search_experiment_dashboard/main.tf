locals {
  dashboard_name    = var.dashboard_name != null ? var.dashboard_name : "SearchExperiment-${var.environment}"
  source            = "SOURCE '${var.log_group_name}'"
  experiment_filter = "filter service = \"search\" and experiment = \"EXPERIMENT_LABEL\""

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
              "## Trade Tariff Search Experiment",
              "All widgets are scoped to the experiment label selected above and the dashboard time range.",
              "**Start here:** compare search volume and latency, then inspect outcomes, questions, search terms, costs, and individual journeys.",
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
            title  = "Search Volume and Outcomes"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event in ["search_completed", "search_failed"]
              | stats count(*) as searches by event, search_type, bin(1h)
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
            title  = "E2E Latency (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "search_completed"
              | stats pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90, pct(total_duration_ms, 99) as p99 by search_type, bin(1h)
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
            title  = "AI Tokens and Cost"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "api_call_completed"
              | stats sum(total_tokens) as tokens, sum(total_cost_usd) as cost_usd by operation, model, bin(1h)
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
            title  = "Final Result Types"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "search_completed"
              | stats count(*) as searches by search_type, results_type, final_result_type
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
            title  = "Questions per Search"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_questions
              | sort total_questions asc
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
            title  = "Result Counts"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "search_completed"
              | stats avg(result_count) as average, median(result_count) as median, sum(if(result_count = 0, 1, 0)) as zero_results by search_type, bin(1h)
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
            title  = "Top Search Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "search_started"
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
            title  = "Questions Returned"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter} and event = "question_returned"
              | fields @timestamp, request_id, effective_query, question_count, attempt_number, iteration, details
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
            title  = "Errors"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter}
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
          y      = 20
          width  = 24
          height = 8
          properties = {
            title  = "Recent Search Journeys"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.experiment_filter}
              | fields @timestamp, request_id, event, search_type, query, effective_query, question_count, answer_count, total_questions, result_count, results_type, final_result_type, total_duration_ms, duration_ms, operation, model, total_tokens, total_cost_usd, error_message, details
              | sort @timestamp desc
              | limit 100
            EOT
          }
        },
      ]
    )
  })
}
