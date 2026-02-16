locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "Search-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""
}

resource "aws_cloudwatch_dashboard" "search" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(

      # Row 0 (y=0): Hero KPI Strip
      [
        {
          type   = "log"
          x      = 0
          y      = 0
          width  = 6
          height = 6
          properties = {
            title  = "Total Searches (Hourly)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 6
          y      = 0
          width  = 6
          height = 6
          properties = {
            title  = "Search Type Split"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by search_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 0
          width  = 6
          height = 6
          properties = {
            title  = "Latency Overview (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90 by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 18
          y      = 0
          width  = 6
          height = 6
          properties = {
            title  = "Search Volume by Outcome"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_failed", "search_completed"]
              | stats count(*) as total by event, bin(1h)
            EOT
          }
        },
      ],

      # Row 1 (y=6): Performance Deep Dive
      [
        {
          type   = "log"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "E2E Latency Percentiles"
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
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "AI API Latency Percentiles"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        },
      ],

      # Row 2 (y=12): Performance by Type + Query Expansion
      [
        {
          type   = "log"
          x      = 0
          y      = 12
          width  = 8
          height = 6
          properties = {
            title  = "Latency by Search Type"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats avg(total_duration_ms) as avg_ms, pct(total_duration_ms, 50) as p50, pct(total_duration_ms, 90) as p90 by search_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 12
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
          x      = 16
          y      = 12
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
      ],

      # Row 3 (y=18): Search Quality - Outcomes
      [
        {
          type   = "log"
          x      = 0
          y      = 18
          width  = 8
          height = 6
          properties = {
            title  = "Final Result Type (Interactive)"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by final_result_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 18
          width  = 8
          height = 6
          properties = {
            title  = "Results Type Breakdown"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats count(*) as searches by results_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 18
          width  = 8
          height = 6
          properties = {
            title  = "Average Result Count"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed"
              | stats avg(result_count) as avg_results, median(result_count) as median_results by bin(1h)
            EOT
          }
        },
      ],

      # Row 4 (y=24): Zero-Result Searches
      [
        {
          type   = "log"
          x      = 0
          y      = 24
          width  = 8
          height = 6
          properties = {
            title  = "Zero-Result Searches by Type"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and result_count = 0
              | stats count(*) as searches by search_type
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 24
          width  = 8
          height = 6
          properties = {
            title  = "Top 30 Zero-Result Search Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and result_count = 0
              | stats count(*) as searches by query
              | sort searches desc
              | limit 30
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 24
          width  = 8
          height = 6
          properties = {
            title  = "Recent Zero-Result Searches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and result_count = 0
              | fields @timestamp, query, search_type, request_id
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
      ],

      # Row 5 (y=30): Interactive Search - The AI Story
      [
        {
          type   = "log"
          x      = 0
          y      = 30
          width  = 12
          height = 6
          properties = {
            title  = "AI Response Types Over Time"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats count(*) as calls by response_type, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 30
          width  = 6
          height = 6
          properties = {
            title  = "Attempts Per Search"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_attempts
              | sort total_attempts asc
            EOT
          }
        },
        {
          type   = "log"
          x      = 18
          y      = 30
          width  = 6
          height = 6
          properties = {
            title  = "Questions Per Search"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_completed" and search_type = "interactive"
              | stats count(*) as searches by total_questions
              | sort total_questions asc
            EOT
          }
        },
      ],

      # Row 6 (y=36): User Journey - Result Selection
      [
        {
          type   = "log"
          x      = 0
          y      = 36
          width  = 8
          height = 6
          properties = {
            title  = "Searches vs Selections"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["search_completed", "result_selected"]
              | stats count(*) as count by event, bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 36
          width  = 8
          height = 6
          properties = {
            title  = "Selected Result Types"
            region = var.region
            view   = "pie"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "result_selected"
              | stats count(*) as selections by goods_nomenclature_class
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 36
          width  = 8
          height = 6
          properties = {
            title  = "Top Selected Codes"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "result_selected"
              | stats count(*) as selections by goods_nomenclature_item_id, goods_nomenclature_class
              | sort selections desc
              | limit 20
            EOT
          }
        },
      ],

      # Row 7 (y=42): Errors and Reliability
      [
        {
          type   = "log"
          x      = 0
          y      = 42
          width  = 6
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
          x      = 6
          y      = 42
          width  = 6
          height = 6
          properties = {
            title  = "Hard Errors Over Time"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "search_failed"
              | stats count(*) as errors by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 42
          width  = 6
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
        {
          type   = "log"
          x      = 18
          y      = 42
          width  = 6
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
      ],

      # Row 8 (y=48): Live Feed
      [
        {
          type   = "log"
          x      = 0
          y      = 48
          width  = 12
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
        {
          type   = "log"
          x      = 12
          y      = 48
          width  = 12
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
