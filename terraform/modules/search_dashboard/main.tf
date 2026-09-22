locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "Search-${var.environment}"
  period         = 300
  namespace      = "TradeTariff/Search"

  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
  search_experiment_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchExperiment-${var.environment}"
  label_dashboard_url             = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  self_text_dashboard_url         = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search" {
  dashboard_name = local.dashboard_name
  dashboard_body = jsonencode(local.dashboard_body)
}

locals {
  dashboard_body = {
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 5
        properties = {
          markdown = join("\n", [
            "## Trade Tariff Search Overview",
            "These charts read `${local.namespace}` metrics emitted when each search event is recorded. Opening this dashboard does not scan `${var.log_group_name}`.",
            "**Collection:** metrics start when this version is running. Earlier dates stay empty. A gap is missing telemetry, not zero traffic. Metrics can take about a minute to appear.",
            "**Counting:** `search_completed`, `search_failed`, `result_selected`, `query_expanded`, and `api_call_completed` increment immediately. A later failure does not remove an earlier count. Use Search Operations for failure investigation. Admin analytics keeps the failure-excluded cohort.",
            "**Empty results:** classic fuzzy/null with zero commodity hits, including a missing commodity count and zero results. Interactive and internal count zero returned results. Exact classic matches are not empty commodity results.",
            "**Series:** UK and XI are separate. Unexpected request sources and search types are recorded as `other`.",
            "**Start here:** use this dashboard for recent trends. Open Operations for active troubleshooting and Quality for intercepts, empty-result terms, and result behaviour.",
            "**Related:** [Search Operations](${local.search_operations_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url}) | [Search Experiments](${local.search_experiment_dashboard_url}) | [Label Generator](${local.label_dashboard_url}) | [Self-Text Generator](${local.self_text_dashboard_url})",
          ])
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 5
        width  = 12
        height = 6
        properties = {
          title   = "Search Volume by Request Source and Outcome"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          stat    = "Sum"
          yAxis   = { left = { label = "Searches", showUnits = false, min = 0 } }
          legend  = { position = "bottom" }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,RequestSource,Outcome} MetricName=\"SearchEvents\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "volume_by_source" }]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 5
        width  = 12
        height = 6
        properties = {
          title   = "Search Volume by Type"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          stat    = "Sum"
          yAxis   = { left = { label = "Searches", showUnits = false, min = 0 } }
          legend  = { position = "bottom" }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,SearchType,Outcome} MetricName=\"SearchEvents\" Environment=\"${var.environment}\" Outcome=\"completed\"', 'Sum', ${local.period})", id = "volume_by_type" }]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 11
        width  = 8
        height = 6
        properties = {
          title   = "Completed vs Failed Searches"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          stat    = "Sum"
          yAxis   = { left = { label = "Searches", showUnits = false, min = 0 } }
          legend  = { position = "bottom" }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Outcome} MetricName=\"SearchEvents\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "completed_failed" }]]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 11
        width  = 8
        height = 6
        properties = {
          title  = "Searches vs Selections"
          region = var.region
          view   = "timeSeries"
          period = local.period
          stat   = "Sum"
          yAxis  = { left = { label = "Events", showUnits = false, min = 0 } }
          metrics = [
            [local.namespace, "SearchEvents", "Environment", var.environment, "Service", "uk", "Outcome", "completed", { stat = "Sum", label = "UK completed" }],
            [local.namespace, "ResultSelections", "Environment", var.environment, "Service", "uk", { stat = "Sum", label = "UK selections" }],
            [local.namespace, "SearchEvents", "Environment", var.environment, "Service", "xi", "Outcome", "completed", { stat = "Sum", label = "XI completed" }],
            [local.namespace, "ResultSelections", "Environment", var.environment, "Service", "xi", { stat = "Sum", label = "XI selections" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 11
        width  = 8
        height = 6
        properties = {
          title  = "Query Expansions"
          region = var.region
          view   = "timeSeries"
          period = local.period
          stat   = "Sum"
          yAxis  = { left = { label = "Expansions", showUnits = false, min = 0 } }
          metrics = [
            [local.namespace, "QueryExpansions", "Environment", var.environment, "Service", "uk", { stat = "Sum", label = "UK" }],
            [local.namespace, "QueryExpansions", "Environment", var.environment, "Service", "xi", { stat = "Sum", label = "XI" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 17
        width  = 8
        height = 6
        properties = {
          title  = "E2E Latency in seconds (p50/p90)"
          region = var.region
          view   = "timeSeries"
          period = local.period
          yAxis  = { left = { label = "Seconds", showUnits = false, min = 0 } }
          metrics = [
            [local.namespace, "SearchDuration", "Environment", var.environment, "Service", "uk", { stat = "p50", label = "UK p50" }],
            [local.namespace, "SearchDuration", "Environment", var.environment, "Service", "uk", { stat = "p90", label = "UK p90" }],
            [local.namespace, "SearchDuration", "Environment", var.environment, "Service", "xi", { stat = "p50", label = "XI p50" }],
            [local.namespace, "SearchDuration", "Environment", var.environment, "Service", "xi", { stat = "p90", label = "XI p90" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 17
        width  = 8
        height = 6
        properties = {
          title  = "AI API Latency in seconds (p50/p90)"
          region = var.region
          view   = "timeSeries"
          period = local.period
          yAxis  = { left = { label = "Seconds", showUnits = false, min = 0 } }
          metrics = [
            [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", "uk", { stat = "p50", label = "UK p50" }],
            [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", "uk", { stat = "p90", label = "UK p90" }],
            [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", "xi", { stat = "p50", label = "XI p50" }],
            [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", "xi", { stat = "p90", label = "XI p90" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 17
        width  = 8
        height = 6
        properties = {
          title   = "Empty Commodity / Empty Result Searches"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          stat    = "Sum"
          yAxis   = { left = { label = "Searches", showUnits = false, min = 0 } }
          legend  = { position = "bottom" }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,SearchType} MetricName=\"EmptyResults\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "empty_results" }]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 23
        width  = 8
        height = 6
        properties = {
          title   = "Average Result Count by Search Type"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          legend  = { position = "bottom" }
          yAxis   = { left = { label = "Results", showUnits = false, min = 0 } }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,SearchType} MetricName=\"ResultCount\" Environment=\"${var.environment}\"', 'Average', ${local.period})", id = "avg_results" }]]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 23
        width  = 8
        height = 6
        properties = {
          title   = "Median Result Count by Search Type"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          legend  = { position = "bottom" }
          yAxis   = { left = { label = "Results", showUnits = false, min = 0 } }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,SearchType} MetricName=\"ResultCount\" Environment=\"${var.environment}\"', 'p50', ${local.period})", id = "median_results" }]]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 23
        width  = 8
        height = 6
        properties = {
          title   = "Average Commodity Result Count by Search Type"
          region  = var.region
          view    = "timeSeries"
          period  = local.period
          legend  = { position = "bottom" }
          yAxis   = { left = { label = "Results", showUnits = false, min = 0 } }
          metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,SearchType} MetricName=\"CommodityResultCount\" Environment=\"${var.environment}\"', 'Average', ${local.period})", id = "avg_commodity_results" }]]
        }
      },
    ]
  }
}
