locals {
  dashboard_name  = var.dashboard_name != null ? var.dashboard_name : "SearchOperations-${var.environment}"
  namespace       = "TradeTariff/Search"
  period          = 300
  services        = ["uk", "xi"]
  source          = "SOURCE '${var.log_group_name}'"
  service_filter  = "filter service = \"search\""
  definitions_url = "https://github.com/trade-tariff/trade-tariff-backend/blob/main/docs/search-dashboards.md"

  dashboard_url   = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${local.dashboard_name}"
  diagnostics_url = "${local.dashboard_url}-Diagnostics"
  overview_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"

  # Each search expression selects one exact dimension set, not its rollups.
  charts = [
    {
      title   = "Completed vs Failed Searches"
      unit    = "Searches"
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Outcome} MetricName=\"SearchEvents\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "searches" }]]
    },
    {
      title = "E2E Latency in seconds (p50/p90/p99)"
      unit  = "Seconds"
      metrics = flatten([for service in local.services : [for stat in ["p50", "p90", "p99"] : {
        series = [local.namespace, "SearchDuration", "Environment", var.environment, "Service", service, { stat = stat, label = "${upper(service)} ${stat}" }]
      }]])[*].series
    },
    {
      title = "AI API Latency in seconds (p50/p90/p99)"
      unit  = "Seconds"
      metrics = flatten([for service in local.services : [for stat in ["p50", "p90", "p99"] : {
        series = [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", service, { stat = stat, label = "${upper(service)} ${stat}" }]
      }]])[*].series
    },
    {
      title   = "Hard Errors"
      unit    = "Errors"
      metrics = [for service in local.services : [local.namespace, "SearchEvents", "Environment", var.environment, "Service", service, "Outcome", "failed", { stat = "Sum", label = upper(service) }]]
    },
    {
      title   = "Query Expansion Volume (including fallback)"
      unit    = "Expansions"
      metrics = [for service in local.services : [local.namespace, "QueryExpansions", "Environment", var.environment, "Service", service, { stat = "Sum", label = upper(service) }]]
    },
    {
      title   = "Query Expansion Average Duration in seconds"
      unit    = "Seconds"
      metrics = [for service in local.services : [local.namespace, "QueryExpansionDuration", "Environment", var.environment, "Service", service, { stat = "Average", label = upper(service) }]]
    },
    {
      title   = "Interactive Search Error Outcomes"
      unit    = "Errors"
      metrics = [for service in local.services : [local.namespace, "InteractiveSearchErrors", "Environment", var.environment, "Service", service, { stat = "Sum", label = upper(service) }]]
    },
    {
      title   = "Query Expansion Timeouts"
      unit    = "Timeouts"
      metrics = [for service in local.services : [local.namespace, "QueryExpansionTimeouts", "Environment", var.environment, "Service", service, { stat = "Sum", label = upper(service) }]]
    },
    {
      title   = "Hybrid Leg Latency in seconds (p50/p90)"
      unit    = "Seconds"
      metrics = [for stat in ["p50", "p90"] : [{ expression = "SEARCH('{${local.namespace},Environment,Service,Leg} MetricName=\"RetrievalDuration\" Environment=\"${var.environment}\"', '${stat}', ${local.period})", id = "latency_${stat}", label = stat }]]
    },
    {
      title   = "Hybrid Leg Failures"
      unit    = "Failures"
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Leg} MetricName=\"RetrievalFailures\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "failures" }]]
    },
    {
      title   = "Hybrid Leg Average Result Counts (successful legs)"
      unit    = "Results"
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Leg} MetricName=\"RetrievalResultCount\" Environment=\"${var.environment}\"', 'Average', ${local.period})", id = "results" }]]
    },
    {
      title   = "AI API Errors by Operation"
      unit    = "Errors"
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Operation,ResponseType} MetricName=\"AiApiCalls\" Environment=\"${var.environment}\" ResponseType=\"error\"', 'Sum', ${local.period})", id = "errors" }]]
    },
    {
      title   = "Duplicate Guard AI Latency in seconds (p50/p90/p99)"
      unit    = "Seconds"
      metrics = [for stat in ["p50", "p90", "p99"] : [{ expression = "SEARCH('{${local.namespace},Environment,Service,Operation} MetricName=\"AiApiDuration\" Environment=\"${var.environment}\" (Operation=\"duplicate_question_validator\" OR Operation=\"duplicate_question_retry\")', '${stat}', ${local.period})", id = "guard_${stat}", label = stat }]]
    },
    {
      title = "Duplicate Guard Fail-Open Rate (all checks)"
      unit  = "Percent"
      # Every check emits 0 or 1. Average therefore uses all checks as its denominator.
      metrics = concat(
        [for service in local.services : [local.namespace, "DuplicateGuardFailOpen", "Environment", var.environment, "Service", service, { stat = "Average", id = "checks_${service}", visible = false }]],
        [for service in local.services : [{ expression = "100 * checks_${service}", id = "rate_${service}", label = upper(service) }]]
      )
    },
    {
      title   = "Duplicate Retry Volume"
      unit    = "Calls"
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Operation,ResponseType} MetricName=\"AiApiCalls\" Environment=\"${var.environment}\" Operation=\"duplicate_question_retry\"', 'Sum', ${local.period})", id = "retries" }]]
    }
  ]

  dashboard_body = {
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 3
        properties = {
          markdown = join("\n", [
            "## Search Operations",
            "Search team: check errors and latency here; open diagnostics for individual requests.",
            "UK and XI are separate. New metrics start at deployment; gaps are not zero. Counts are events, not unique journeys.",
            "[Diagnostics](${local.diagnostics_url}) | [Overview](${local.overview_url}) | [Definitions](${local.definitions_url})",
          ])
        }
      }
      ], [for index, chart in local.charts : {
        type = "metric", x = (index % 3) * 8, y = 3 + floor(index / 3) * 6, width = 8, height = 6
        properties = {
          title   = chart.title, region = var.region, view = "timeSeries", period = local.period
          metrics = chart.metrics
          legend  = { position = "bottom" }
          yAxis   = { left = { label = chart.unit, showUnits = false, min = 0 } }
        }
    }])
  }
}

resource "aws_cloudwatch_dashboard" "search_operations" {
  dashboard_name = local.dashboard_name
  dashboard_body = jsonencode(local.dashboard_body)
}
