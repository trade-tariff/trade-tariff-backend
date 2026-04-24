locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "Search-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""

  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
  label_dashboard_url             = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  self_text_dashboard_url         = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search" {
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
              "## Trade Tariff Search Overview",
              "Long-range search health dashboard for quarter-scale trend viewing. Follows the RED method (Rate, Errors, Duration).",
              "**Healthy:** p90 latency < 5s, hard failures stay low, zero-result trends stable, and selections broadly track search volume.",
              "**Start here:** use this dashboard for 3-month trends. Open Operations for active troubleshooting and Quality for intercepts, zero-result terms, and result behaviour.",
              "**Related:** [Search Operations](${local.search_operations_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url}) | [Label Generator](${local.label_dashboard_url}) | [Self-Text Generator](${local.self_text_dashboard_url})",
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
            title  = "Total Searches"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by bin(1d)
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
            title  = "Search Volume by Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by search_type, bin(1d)
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
            title  = "Completed vs Failed Searches"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_completed", "search_failed"]
              | stats count(*) as count by event, bin(1d)
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
            title  = "Searches vs Selections"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_completed", "result_selected"]
              | stats count(*) as count by event, bin(1d)
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
            title  = "E2E Latency (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90 by bin(1d)
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
            title  = "AI API Latency (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90 by bin(1d)
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
            title  = "Query Expansions"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "query_expanded"
              | stats count(*) as expansions by bin(1d)
            EOT
          }
        },
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "Zero-Result Searches"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and result_count = 0
              | stats count(*) as searches by search_type, bin(1d)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "Average Result Count"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats avg(result_count) as avg_results, median(result_count) as median_results by bin(1d)
            EOT
          }
        },
      ]
    )
  })
}
