locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "Search-${var.environment}"
  period         = 300
  namespace      = "TradeTariff/Search"

  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
  search_experiment_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchExperiment-${var.environment}"
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
        height = 3
        properties = {
          markdown = join("\n", [
            "## Search Overview",
            "Search team: track traffic, outcomes and latency. Metrics separate UK and XI. Experiment activity below combines frontend sessions and runs one log query.",
            "Metrics start at deployment; gaps are not zero. Counts are events, not unique journeys, and include degraded searches.",
            "[Operations](${local.search_operations_dashboard_url}) | [Quality](${local.search_quality_dashboard_url}) | [Experiments](${local.search_experiment_dashboard_url}) | [Definitions](https://github.com/trade-tariff/trade-tariff-backend/blob/main/docs/search-dashboards.md)",
          ])
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 3
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
        y      = 3
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
        y      = 9
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
        y      = 9
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
        y      = 9
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
        y      = 15
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
        y      = 15
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
        y      = 15
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
        y      = 21
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
        y      = 21
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
        y      = 21
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
      {
        type = "text", x = 0, y = 27, width = 24, height = 2
        properties = {
          markdown = "## Active experiments\nEstimated sessions with a visible guided-search page in the selected range, not people or all enrolments. Top 30 labels; sessions can appear under multiple labels. Unlabelled events are excluded."
        }
      },
      {
        type = "log", x = 0, y = 29, width = 24, height = 8
        properties = {
          title  = "Active browser sessions by experiment"
          region = var.region
          view   = "bar"
          query  = <<-EOT
            SOURCE '${var.log_group_name}'
            | filter event = "guided_search.journey" and schema_version = 1 and outcome = "page_visible"
            | filter browser_session_id like /^v1:[0-9a-f]{64}$/ and experiment like /\S/
            | stats count_distinct(browser_session_id) as estimated_active_browser_sessions by experiment
            | sort estimated_active_browser_sessions desc
            | limit 30
          EOT
        }
      },
    ]
  }
}
