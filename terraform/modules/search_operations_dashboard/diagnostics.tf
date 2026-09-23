locals {
  diagnostic_charts = [
    {
      title = "Recent Error Log"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter}
        | filter event in ["search_failed", "search_stage_failed", "query_expansion_timed_out"] or (event = "search_completed" and final_result_type = "error") or (event = "api_call_completed" and response_type = "error")
        | fields @timestamp, event, request_source, search_type, failure_code, operation, error_type, error_message, timeout_ms, elapsed_ms, fallback_outcome, request_id
        | sort @timestamp desc
        | limit 30
      EOT
    },
    {
      title = "Hard Errors by Type"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter} and event = "search_failed"
        | stats count(*) as errors by error_type
        | sort errors desc
        | limit 30
      EOT
    },
    {
      title = "Query Expansion Detail in seconds"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter} and event = "query_expanded"
        | stats count(*) as expansions, avg(duration_ms / 1000) as avg_seconds by reason
        | sort expansions desc
        | limit 30
      EOT
    },
    {
      title = "Recent Searches"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter} and event = "search_started"
        | stats latest(@timestamp) as latest_timestamp,
            latest(request_source) as latest_request_source, latest(search_type) as latest_search_type
          by request_id
        | display latest_timestamp, latest_request_source, latest_search_type, request_id
        | sort latest_timestamp desc
        | limit 30
      EOT
    },
    {
      title = "Recent Duplicate Guard AI Issues"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter}
        | filter (event = "api_call_completed" and operation in ["duplicate_question_validator", "duplicate_question_retry"] and response_type = "error") or (event = "duplicate_question_guard_checked" and reason = "validator_unparseable")
        | fields @timestamp, event, request_id, operation, response_type, reason, error_type, error_message, attempt_number
        | sort @timestamp desc
        | limit 30
      EOT
    },
    {
      title = "Recent Completions"
      query = <<-EOT
        ${local.source}
        | ${local.service_filter} and event = "search_completed"
        | fields @timestamp, request_source, search_type, total_duration_ms, result_count, final_result_type, request_id
        | sort @timestamp desc
        | limit 30
      EOT
    }
  ]

  diagnostics_body = {
    start = "-PT1H"
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 3
        properties = {
          markdown = join("\n", [
            "## Search Diagnostics",
            "Search team: inspect recent failures, then use the request ID in admin search diagnostics.",
            "Log queries run when opened. Each table shows at most 30 rows. One failure can produce several events.",
            "[Operations](${local.dashboard_url}) | [Definitions](${local.definitions_url})",
          ])
        }
      }
      ], [for index, chart in local.diagnostic_charts : {
        type       = "log", x = (index % 2) * 12, y = 3 + floor(index / 2) * 6, width = 12, height = 6
        properties = { title = chart.title, query = chart.query, region = var.region, view = "table" }
    }])
  }
}

resource "aws_cloudwatch_dashboard" "search_diagnostics" {
  dashboard_name = "${local.dashboard_name}-Diagnostics"
  dashboard_body = jsonencode(local.diagnostics_body)
}
