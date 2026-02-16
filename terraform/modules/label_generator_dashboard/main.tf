locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "LabelGenerator-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"label_generator\""

  self_text_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
  search_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "label_generator" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(

      # Row 0 (y=0): Documentation
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = join("\n", [
              "## Label Generator",
              "AI-powered contextual label generation for goods nomenclatures. Runs as paginated Sidekiq jobs on the sync queue.",
              "**Healthy:** all pages succeed, API latency p90 < 30s, no label save failures.",
              "**Start here:** check Page Success vs Failure trend and API Latency, then drill into failure tables below.",
              "**Related:** [Self-Text Generator](${local.self_text_dashboard_url}) | [Search](${local.search_dashboard_url})",
            ])
          }
        }
      ],

      # Row 1 (y=2): KPI Strip - trends at a glance
      [
        {
          type   = "log"
          x      = 0
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "Page Success vs Failure"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["page_completed", "page_failed"]
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
            title  = "API Latency (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90 by bin(1h)
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
            title  = "Labels Created vs Failed"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "page_completed"
              | stats sum(labels_created) as created, sum(labels_failed) as failed by bin(1h)
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
            title  = "Error Rate by Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["page_failed", "api_call_failed", "label_save_failed"]
              | stats count(*) as errors by event, bin(1h)
            EOT
          }
        }
      ],

      # Row 2 (y=8): Performance deep dive
      [
        {
          type   = "log"
          x      = 0
          y      = 8
          width  = 12
          height = 6
          properties = {
            title  = "Page Processing Percentiles (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "page_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 8
          width  = 12
          height = 6
          properties = {
            title  = "API Latency Percentiles (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        }
      ],

      # Row 3 (y=14): Quality - mismatches and generation history
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "AI Result Mismatches"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_completed" and batch_size != results_count
              | fields @timestamp, page_number, batch_size, results_count, model
              | sort @timestamp desc
              | limit 50
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
            title  = "Recent Generation Runs"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "generation_completed"
              | fields @timestamp, total_pages, duration_ms
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ],

      # Row 4 (y=20): Drill-down - failure details
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "API Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_failed"
              | fields @timestamp, page_number, model, error_class, error_message, duration_ms
              | sort @timestamp desc
              | limit 20
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
            title  = "Page Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "page_failed"
              | fields @timestamp, page_number, error_class, error_message, ai_response
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
            title  = "Label Save Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "label_save_failed"
              | fields @timestamp, page_number, goods_nomenclature_item_id, error_class, error_message, validation_errors
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ]
    )
  })
}
