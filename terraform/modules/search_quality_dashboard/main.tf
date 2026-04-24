locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SearchQuality-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"search\""

  search_dashboard_url            = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  search_operations_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SearchOperations-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "search_quality" {
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
              "## Trade Tariff Search Quality",
              "Behaviour and product-quality dashboard for search outcomes, zero-result terms, intercepts, and result selection patterns.",
              "**Healthy:** zero-result terms stay stable, result types remain consistent, intercept matches track expected terms, and interactive outcomes do not skew towards errors.",
              "**Start here:** check result-type and zero-result widgets first, then inspect intercept and selection drill-downs below.",
              "**Related:** [Search Overview](${local.search_dashboard_url}) | [Search Operations](${local.search_operations_dashboard_url})",
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
          y      = 2
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
          y      = 2
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
      [
        {
          type   = "log"
          x      = 0
          y      = 8
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
          y      = 8
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
          y      = 8
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
      [
        {
          type   = "log"
          x      = 0
          y      = 14
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
          y      = 14
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
          y      = 14
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
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Intercept Checks Over Time"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked"
              | stats count(*) as checks by matched, bin(1h)
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
            title  = "Intercept Outcomes"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | stats count(*) as matches by excluded, filtering, guidance_level, guidance_location, escalate_to_webchat
              | sort matches desc
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
            title  = "Top Matched Intercept Terms"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | stats count(*) as matches by term, excluded, filtering, guidance_level, guidance_location, escalate_to_webchat
              | sort matches desc
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
          y      = 26
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
          y      = 26
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
      [
        {
          type   = "log"
          x      = 0
          y      = 32
          width  = 24
          height = 6
          properties = {
            title  = "Recent Intercept Matches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "description_intercept_checked" and matched = true
              | fields @timestamp, query, term, excluded, filtering, filter_prefix_count, guidance_level, guidance_location, escalate_to_webchat, request_id
              | sort @timestamp desc
              | limit 30
            EOT
          }
        },
      ]
    )
  })
}
