locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "TariffNotePipeline-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"customs_tariff_importer\""

  tariff_sync_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=TariffSync-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "tariff_note_pipeline" {
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
              "## Tariff Note Pipeline RED Dashboard",
              "CloudWatch Logs Insights dashboard for the tariff note document import and admin review pipeline.",
              "**Healthy:** import runs complete, failed event volume stays at zero, and p90 import/parse/fetch duration remains stable.",
              "**Start here:** check Rate, Errors, and Duration in the first row. Use the drill-down tables for failed documents and operator status changes.",
              "**Related:** [Tariff Sync](${local.tariff_sync_dashboard_url})",
            ])
          }
        }
      ],

      # RED row: request rate, errors and duration.
      [
        {
          type   = "log"
          x      = 0
          y      = 2
          width  = 6
          height = 6
          properties = {
            title  = "Rate: Pipeline Events"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["import_run_started", "import_run_completed", "document_imported", "document_skipped", "status_changed", "section_note_updated"]
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
            title  = "Errors: Failed Events"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["import_run_failed", "fetch_failed", "parse_failed", "document_import_failed"]
              | stats count(*) as errors by event, bin(1h)
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
            title  = "Duration: Run p50/p90/p99 (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "import_run_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
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
            title  = "Recent Import Runs"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "import_run_completed"
              | fields @timestamp, imported, skipped, failed, duration_ms
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ],

      # Import phase breakdown.
      [
        {
          type   = "log"
          x      = 0
          y      = 8
          width  = 8
          height = 6
          properties = {
            title  = "Fetch Duration p50/p90/p99 (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "document_fetched"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
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
            title  = "Parse Duration p50/p90/p99 (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "document_parsed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
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
            title  = "Document Import Duration p50/p90/p99 (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "document_imported"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90, pct(duration_ms, 99) as p99 by bin(1h)
            EOT
          }
        }
      ],

      # Content and review activity.
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Extracted Content Counts"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "document_parsed"
              | stats max(chapters) as chapters, max(sections) as sections, max(rules) as rules by version, bin(1h)
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
            title  = "Admin Status Changes"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "status_changed"
              | stats count(*) as changes by from_status, to_status, bin(1h)
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
            title  = "Section Note Edits"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "section_note_updated"
              | stats count(*) as edits by version, bin(1h)
            EOT
          }
        }
      ],

      # Drill-down tables.
      [
        {
          type   = "log"
          x      = 0
          y      = 20
          width  = 8
          height = 6
          properties = {
            title  = "Recent Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["import_run_failed", "fetch_failed", "parse_failed", "document_import_failed"]
              | fields @timestamp, event, version, url, error_class, error_message
              | sort @timestamp desc
              | limit 30
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
            title  = "Recent Document Outcomes"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["document_imported", "document_skipped", "document_import_failed"]
              | fields @timestamp, event, version, reason, duration_ms, error_class, error_message
              | sort @timestamp desc
              | limit 30
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
            title  = "Recent Admin Changes"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["status_changed", "section_note_updated"]
              | fields @timestamp, event, version, from_status, to_status, section_id, note_id, whodunnit
              | sort @timestamp desc
              | limit 30
            EOT
          }
        }
      ]
    )
  })
}
