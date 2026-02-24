locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "TariffSync-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"tariff_sync\""

  label_dashboard_url     = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  search_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  self_text_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "tariff_sync" {
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
              "## Tariff Sync Pipeline",
              "Daily CDS/TARIC update download and apply. Runs as Sidekiq workers triggered by cron.",
              "**Healthy:** sync runs complete without failures, apply duration < 5min, no download retries.",
              "**Start here:** check Sync Run Success vs Failure, then Apply Duration. Drill into failure tables below.",
              "**Related:** [Label Generator](${local.label_dashboard_url}) | [Self-Text Generator](${local.self_text_dashboard_url}) | [Search](${local.search_dashboard_url})",
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
            title  = "Sync Run Success vs Failure"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["sync_run_completed", "sync_run_failed"]
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
            title  = "Files Applied"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "apply_completed"
              | stats sum(files_applied) as files_applied by bin(1h)
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
            title  = "Total Errors"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["sync_run_failed", "download_failed", "file_import_failed", "sequence_check_failed", "failed_updates_detected"]
              | stats count(*) as errors by bin(1h)
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
            title  = "Apply Duration (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "apply_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90 by bin(1h)
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
            title  = "Download Duration Percentiles (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "download_completed"
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
            title  = "Per-File Import Duration Percentiles (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "file_import_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        }
      ],

      # Row 3 (y=14): Error breakdown + operations
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "Errors by Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["sync_run_failed", "download_failed", "file_import_failed", "sequence_check_failed", "failed_updates_detected"]
              | stats count(*) as errors by event, bin(1h)
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
            title  = "Records by Operation"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "file_import_completed"
              | stats sum(creates) as creates, sum(updates) as updates, sum(destroys) as destroys by bin(1h)
            EOT
          }
        }
      ],

      # Row 4 (y=20): Drill-down tables
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "Recent Sync Runs"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "sync_run_completed"
              | fields @timestamp, trade_service, run_id, duration_ms, files_downloaded, files_applied
              | sort @timestamp desc
              | limit 20
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "Recent Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["sync_run_failed", "download_failed", "file_import_failed", "sequence_check_failed", "failed_updates_detected"]
              | fields @timestamp, trade_service, event, error_class, error_message, filename
              | sort @timestamp desc
              | limit 30
            EOT
          }
        }
      ]
    )
  })
}
