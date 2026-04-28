locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SearchOperations-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""

  search_dashboard_url         = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_quality_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_operations" {
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
              "## Trade Tariff Search Operations",
              "Recent operational troubleshooting dashboard for search. Use this for live incidents, latency spikes, and error investigation.",
              "**Healthy:** p90 latency < 5s, API latency p90 < 5s, low hard-error volume, and hybrid retrieval failures near zero.",
              "**Start here:** check completed vs failed searches and latency rows first, then drill into error and recent-event tables below.",
              "**Related:** [Search Overview](${local.search_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url})",
            ])
          }
        }
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "Completed vs Failed Searches"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_completed", "search_failed"]
              | stats count(*) as count by event, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 6
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "E2E Latency (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90, pct(total_duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "AI API Latency (p50/p90/p99)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 18
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "Hard Errors"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_failed"
              | stats count(*) as errors by bin(1h)
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
            title  = "Query Expansion Volume"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "query_expanded"
              | stats count(*) as expansions, avg(duration_ms) as avg_duration_ms by bin(1h)
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
            title  = "Interactive Search Errors"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive" and final_result_type = "error"
              | stats count(*) as errors by bin(1h)
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
            title  = "Hard Errors by Type"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_failed"
              | stats count(*) as errors by error_type
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
            title  = "Hybrid Leg Latency (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "retrieval_leg_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90 by leg, bin(1h)
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
            title  = "Hybrid Leg Failures"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "retrieval_leg_completed" and status = "error"
              | stats count(*) as failures by leg, bin(1h)
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
            title  = "Hybrid Leg Result Counts"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "retrieval_leg_completed" and status = "success"
              | stats avg(result_count) as avg_results by leg, bin(1h)
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
            title  = "Query Expansion Detail"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "query_expanded"
              | stats count(*) as expansions, avg(duration_ms) as avg_ms by reason
              | sort expansions desc
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
            title  = "Recent Error Log"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_failed", "search_completed"]
              | filter event = "search_failed" or final_result_type = "error"
              | fields @timestamp, event, search_type, error_type, final_result_type, error_message, request_id
              | sort @timestamp desc
              | limit 20
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
            title  = "Recent Searches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_started"
              | fields @timestamp, query, search_type, request_id
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
          y      = 26
          width  = 24
          height = 6
          properties = {
            title  = "Recent Completions"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | fields @timestamp, search_type, total_duration_ms, result_count, final_result_type, request_id
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
      ]
    )
  })
}
