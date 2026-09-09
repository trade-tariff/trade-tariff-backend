locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "Search-${var.environment}"
  source         = "FROM `${var.log_group_name}`"
  service_filter = "service = 'search' AND ${local.request_exclusion_filter}"
  request_exclusion_filter = templatefile("${path.module}/../../../app/services/search_analytics/request_exclusion_filter.sql.tftpl", {
    log_group_name  = var.log_group_name
    scope_condition = "1 = 1"
  })
  # Classic empty commodity results: fuzzy/null with commodity_result_count = 0 (empty Best commodity matches).
  # Includes completely empty results and headings/chapters-only; excludes exact matches.
  # Interactive empty results: result_count = 0 (filter also accepts search_type=internal for forward-compat).
  # Historical classic falls back to result_count = 0.
  # Keep in sync with SearchAnalytics::CloudwatchSnapshotQuery#zero_result_condition
  # and the other search_*_dashboard modules.
  classic_empty_commodity_condition = "(search_type = 'classic' and ((commodity_result_count IS NOT NULL and commodity_result_count = 0 and (results_type IS NULL or results_type != 'exact_search')) or (commodity_result_count IS NULL and result_count = 0)))"
  interactive_no_results_condition  = "((search_type = 'interactive' or search_type = 'internal') and result_count = 0)"
  zero_result_condition             = "(${local.classic_empty_commodity_condition} or ${local.interactive_no_results_condition})"

  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
  search_quality_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchQuality-${var.environment}"
  search_experiment_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchExperiment-${var.environment}"
  label_dashboard_url             = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  self_text_dashboard_url         = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode(local.rendered_dashboard_body)
}

locals {
  rendered_dashboard_body = merge(local.dashboard_body, {
    widgets = [for widget in local.dashboard_body.widgets : widget.type == "log" ? merge(widget, {
      properties = merge(widget.properties, { queryLanguage = "SQL", query = "SOURCE '${var.log_group_name}' | ${widget.properties.query}" })
    }) : widget]
  })
  dashboard_body = {
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
              "Long-range search trends excluding every event for request IDs with a recorded search failure in the selected time range. Use the complete journey window; older and uncorrelated logs remain included when no failure can be linked. Operations retains all failures.",
              "**Read these trends:** compare latency, empty results and selections within the retained cohort. Use Search Operations for failure counts and operational health; excluded failures cannot be assessed here.",
              "**Empty commodity results (classic):** fuzzy/null with zero commodity hits (empty Best commodity matches; includes fully empty and headings/chapters-only). **Empty results (interactive):** no returned results. See Search Quality for classic empty-kind pies and free-text rates.",
              "**Start here:** use this dashboard for 3-month trends. Open Operations for active troubleshooting and Quality for intercepts, empty commodity/empty result terms, and result behaviour.",
              "**Related:** [Search Operations](${local.search_operations_dashboard_url}) | [Search Quality](${local.search_quality_dashboard_url}) | [Search Experiments](${local.search_experiment_dashboard_url}) | [Label Generator](${local.label_dashboard_url}) | [Self-Text Generator](${local.self_text_dashboard_url})",
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
            title  = "Search Volume by Request Source and Outcome"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS searches, COALESCE(request_source, 'unknown') AS request_source, event
              ${local.source} WHERE ${local.service_filter} AND event IN ('search_completed', 'search_failed')
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), COALESCE(request_source, 'unknown'), event
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
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS searches, search_type
              ${local.source} WHERE ${local.service_filter} AND event = 'search_completed'
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), search_type
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
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS count, event
              ${local.source} WHERE ${local.service_filter} AND event IN ('search_completed', 'search_failed')
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), event
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
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS count, event
              ${local.source} WHERE ${local.service_filter} AND event IN ('search_completed', 'result_selected')
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), event
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
            title  = "E2E Latency in seconds (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, PERCENTILE_APPROX(total_duration_ms / 1000, 0.5) AS p50_seconds, PERCENTILE_APPROX(total_duration_ms / 1000, 0.9) AS p90_seconds
              ${local.source} WHERE ${local.service_filter} AND event = 'search_completed'
              GROUP BY DATE_TRUNC('DAY', `@timestamp`)
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
            title  = "AI API Latency in seconds (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, PERCENTILE_APPROX(duration_ms / 1000, 0.5) AS p50_seconds, PERCENTILE_APPROX(duration_ms / 1000, 0.9) AS p90_seconds
              ${local.source} WHERE ${local.service_filter} AND event = 'api_call_completed'
              GROUP BY DATE_TRUNC('DAY', `@timestamp`)
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
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS expansions
              ${local.source} WHERE ${local.service_filter} AND event = 'query_expanded'
              GROUP BY DATE_TRUNC('DAY', `@timestamp`)
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
            title  = "Empty Commodity / Empty Result Searches"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, COUNT(*) AS searches, search_type
              ${local.source} WHERE ${local.service_filter} AND event = 'search_completed' AND ${local.zero_result_condition}
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), search_type
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
            title  = "Average Result Count by Search Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              SELECT DATE_TRUNC('DAY', `@timestamp`) AS bucket, AVG(result_count) AS avg_results, PERCENTILE_APPROX(result_count, 0.5) AS median_results, AVG(commodity_result_count) AS avg_commodity_results, search_type
              ${local.source} WHERE ${local.service_filter} AND event = 'search_completed'
              GROUP BY DATE_TRUNC('DAY', `@timestamp`), search_type
            EOT
          }
        },
      ]
    )
  }
}
