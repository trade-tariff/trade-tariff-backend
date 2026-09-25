locals {
  dashboard_name  = var.dashboard_name != null ? var.dashboard_name : "SearchOperations-${var.environment}"
  namespace       = "TradeTariff/Search"
  period          = 300
  services        = ["uk", "xi"]
  source          = "SOURCE '${var.log_group_name}'"
  service_filter  = "filter service = \"search\""
  definitions_url = "https://github.com/trade-tariff/trade-tariff-backend/blob/main/docs/search-dashboards.md"
  colors          = { uk = "#1f77b4", xi = "#ff7f0e" }
  percentile_colors = {
    uk = { p50 = "#9ecae1", p90 = "#3182bd", p99 = "#08519c" }
    xi = { p50 = "#fdae6b", p90 = "#e6550d", p99 = "#a63603" }
  }
  operations = {
    search_query_expansion          = "Expansion"
    interactive_search              = "Questions / answers"
    interactive_search_final_answer = "Final answer"
    duplicate_question_validator    = "Duplicate validator"
    duplicate_question_retry        = "Duplicate retry"
  }

  dashboard_url   = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${local.dashboard_name}"
  diagnostics_url = "${local.dashboard_url}-Diagnostics"
  overview_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"

  # A binary sample for every terminal interactive/internal request provides
  # both the error numerator and its denominator with identical coverage.
  request_volume = [for service in local.services : [local.namespace, "GuidedSearchErrors", "Environment", var.environment, "Service", service, { stat = "SampleCount", label = upper(service), color = local.colors[service] }]]
  request_error_percentage = concat(
    [for service in local.services : [local.namespace, "GuidedSearchErrors", "Environment", var.environment, "Service", service, { stat = "Average", id = "errors_${service}", visible = false }]],
    [for service in local.services : [{ expression = "100 * errors_${service}", id = "rate_${service}", label = upper(service), color = local.colors[service] }]]
  )

  charts = concat([
    {
      title = "Finished requests (selected range)", unit = "Requests", x = 0, y = 3, width = 12, height = 3
      view  = "singleValue", whole_range = true, metrics = local.request_volume
    },
    {
      title = "Errors (% of finished requests, selected range)", unit = "Percent", x = 12, y = 3, width = 12, height = 3
      view  = "singleValue", whole_range = true, metrics = local.request_error_percentage
    },
    {
      title   = "Finished requests per 5 minutes", unit = "Requests / 5 min", x = 0, y = 8, width = 12
      metrics = local.request_volume
    },
    {
      title = "Recorded outcomes (selected range)", unit = "Events", x = 12, y = 8, width = 12
      view  = "bar", whole_range = true
      metrics = flatten([for outcome in ["answers", "questions", "error", "hard_failure", "unknown", "other"] : [for service in local.services : {
        series = [local.namespace, "GuidedSearchOutcomes", "Environment", var.environment, "Service", service, "GuidedOutcome", outcome, { stat = "Sum", label = "${upper(service)} ${outcome}", color = local.colors[service] }]
      }]])[*].series
    },
    {
      title   = "Errors (% of finished requests)", unit = "Percent", x = 0, y = 14, width = 12
      metrics = local.request_error_percentage
    },
    {
      title = "Completed server request latency (seconds, p50/p90/p99)", unit = "Seconds", x = 12, y = 14, width = 12
      metrics = flatten([for service in local.services : [for stat in ["p50", "p90", "p99"] : {
        series = [local.namespace, "GuidedSearchDuration", "Environment", var.environment, "Service", service, { stat = stat, label = "${upper(service)} ${stat}", color = local.percentile_colors[service][stat] }]
      }]])[*].series
    }
    ], [for index, operation in ["search_query_expansion", "interactive_search", "interactive_search_final_answer"] : {
      title = "${local.operations[operation]} AI latency (seconds, p50/p90)", unit = "Seconds", x = index * 8, y = 22, width = 8
      metrics = flatten([for service in local.services : [for stat in ["p50", "p90"] : {
        series = [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", service, "Operation", operation, { stat = stat, label = "${upper(service)} ${stat}", color = local.percentile_colors[service][stat] }]
      }]])[*].series
    }], [
    {
      title = "AI errors by operation (selected range)", unit = "Errors", x = 0, y = 28, width = 12
      view  = "bar", whole_range = true
      metrics = flatten([for operation, label in local.operations : [for service in local.services : {
        series = [local.namespace, "AiApiCalls", "Environment", var.environment, "Service", service, "Operation", operation, "ResponseType", "error", { stat = "Sum", label = "${upper(service)} ${label}", color = local.colors[service] }]
      }]])[*].series
    },
    {
      title   = "Retrieval failures per 5 minutes", unit = "Failures / 5 min", x = 12, y = 28, width = 12
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Leg} MetricName=\"RetrievalFailures\" Environment=\"${var.environment}\"', 'Sum', ${local.period})", id = "failures" }]]
    },
    {
      title = "Retrieval latency (seconds, p50/p90)", unit = "Seconds", x = 0, y = 34, width = 12
      metrics = flatten([for service in local.services : [for leg in ["opensearch", "vector", "unknown", "other"] : [for stat in ["p50", "p90"] : {
        series = [local.namespace, "RetrievalDuration", "Environment", var.environment, "Service", service, "Leg", leg, { stat = stat, label = "${upper(service)} ${leg} ${stat}" }]
      }]]])[*].series
    },
    {
      title   = "Mean results per successful retrieval", unit = "Results / successful leg", x = 12, y = 34, width = 12
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Leg} MetricName=\"RetrievalResultCount\" Environment=\"${var.environment}\"', 'Average', ${local.period})", id = "results" }]]
    },
    {
      title   = "Expansions per 5 minutes (including fallback)", unit = "Expansions / 5 min", x = 0, y = 42, width = 8
      metrics = [for service in local.services : [local.namespace, "QueryExpansions", "Environment", var.environment, "Service", service, { stat = "Sum", label = upper(service), color = local.colors[service] }]]
    },
    {
      title   = "Expansion timeouts per 5 minutes", unit = "Timeouts / 5 min", x = 8, y = 42, width = 8
      metrics = [for service in local.services : [local.namespace, "QueryExpansionTimeouts", "Environment", var.environment, "Service", service, { stat = "Sum", label = upper(service), color = local.colors[service] }]]
    },
    {
      title = "Expansion elapsed time (seconds, p50/p90)", unit = "Seconds", x = 16, y = 42, width = 8
      metrics = flatten([for service in local.services : [for stat in ["p50", "p90"] : {
        series = [local.namespace, "QueryExpansionDuration", "Environment", var.environment, "Service", service, { stat = stat, label = "${upper(service)} ${stat}", color = local.percentile_colors[service][stat] }]
      }]])[*].series
    },
    {
      title = "Fail-open (% of validator-eligible checks)", unit = "Percent", x = 0, y = 48, width = 12
      metrics = concat(
        [for service in local.services : [local.namespace, "DuplicateValidatorFailOpen", "Environment", var.environment, "Service", service, { stat = "Average", id = "checks_${service}", visible = false }]],
        [for service in local.services : [{ expression = "100 * checks_${service}", id = "rate_${service}", label = upper(service), color = local.colors[service] }]]
      )
    },
    {
      title   = "Validator-eligible checks per 5 minutes", unit = "Checks / 5 min", x = 12, y = 48, width = 12
      metrics = [for service in local.services : [local.namespace, "DuplicateValidatorFailOpen", "Environment", var.environment, "Service", service, { stat = "SampleCount", label = upper(service), color = local.colors[service] }]]
    },
    {
      title = "Duplicate guard AI latency (seconds, p50/p90)", unit = "Seconds", x = 0, y = 54, width = 12
      metrics = flatten([for service in local.services : [for operation in ["duplicate_question_validator", "duplicate_question_retry"] : [for stat in ["p50", "p90"] : {
        series = [local.namespace, "AiApiDuration", "Environment", var.environment, "Service", service, "Operation", operation, { stat = stat, label = "${upper(service)} ${local.operations[operation]} ${stat}" }]
      }]]])[*].series
    },
    {
      title   = "Duplicate retry calls per 5 minutes", unit = "Calls / 5 min", x = 12, y = 54, width = 12
      metrics = [[{ expression = "SEARCH('{${local.namespace},Environment,Service,Operation,ResponseType} MetricName=\"AiApiCalls\" Environment=\"${var.environment}\" Operation=\"duplicate_question_retry\"', 'Sum', ${local.period})", id = "retries" }]]
    }
  ])

  dashboard_body = {
    start          = "-PT3H"
    periodOverride = "inherit"
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 3
        properties = {
          markdown = join("\n", [
            "## Search Operations",
            "On-call: start with interactive/internal request health, then locate dependency failures. UK and XI stay separate.",
            "New metrics start at deployment; gaps are not zero. Requests are server calls, not whole user journeys. New hmrc-users searches are omitted.",
            "[Diagnostics](${local.diagnostics_url}) | [Overview](${local.overview_url}) | [Definitions](${local.definitions_url})",
          ])
        }
      }
      ], [for section in [
        { y = 6, text = "## Request health\nInteractive/internal terminal events only. Errors include exceptions and returned error outcomes. Completed calls can return questions, answers or errors. Latency excludes exceptions." },
        { y = 20, text = "## Dependencies\nShared search dependencies, including evaluation callers. Compare like operations; these counts are not unique failed requests. Sparse percentiles need caution." },
        { y = 40, text = "## Fallbacks and duplicate checks\nSupporting signals, not success measures. Validator eligibility means suspicious=true; disabled and non-suspicious checks are excluded from its percentage." },
        ] : {
        type       = "text", x = 0, y = section.y, width = 24, height = 2
        properties = { markdown = section.text }
        }], [for chart in local.charts : {
        type = "metric", x = chart.x, y = chart.y, width = chart.width, height = try(chart.height, 6)
        properties = merge({
          title   = chart.title, region = var.region, view = try(chart.view, "timeSeries"), period = local.period
          metrics = chart.metrics, stacked = false
          legend  = { position = "bottom" }
          yAxis   = { left = merge({ label = chart.unit, showUnits = false, min = 0 }, chart.unit == "Percent" ? { max = 100 } : {}) }
        }, try(chart.whole_range, false) ? { setPeriodToTimeRange = true } : {})
    }])
  }
}

resource "aws_cloudwatch_dashboard" "search_operations" {
  dashboard_name = local.dashboard_name
  dashboard_body = jsonencode(local.dashboard_body)
}
