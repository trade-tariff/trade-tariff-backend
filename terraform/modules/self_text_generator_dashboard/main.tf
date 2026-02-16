locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "self_text_generator" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
      # Row 1: Overview
      [
        {
          type   = "log"
          x      = 0
          y      = 0
          width  = 8
          height = 6
          properties = {
            title  = "Generation Runs"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | fields @timestamp, total_chapters
              | filter service = "self_text_generator" and event = "generation_started"
              | sort @timestamp desc
              | limit 20
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 0
          width  = 8
          height = 6
          properties = {
            title  = "Chapter Success/Failure"
            region = var.region
            query  = "SOURCE '${var.log_group_name}' | filter service = 'self_text_generator' and event in ['chapter_completed', 'chapter_failed'] | stats count(*) as count by event"
            view   = "pie"
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 0
          width  = 8
          height = 6
          properties = {
            title  = "Error Summary"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event in ["chapter_failed", "api_call_failed"]
              | stats count(*) as count by event, error_class
              | sort count desc
            EOT
          }
        }
      ],

      # Row 2: Chapter processing metrics
      [
        {
          type   = "log"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "Chapter Processing Times (ms)"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event = "chapter_completed"
              | fields @timestamp, chapter_code, duration_ms, mechanical.processed, ai.processed, ai.failed
              | sort @timestamp desc
              | limit 100
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
            title  = "API Call Latency (ms)"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event = "api_call_completed"
              | fields @timestamp, duration_ms, chapter_code, batch_size, model
              | sort @timestamp desc
              | limit 50
            EOT
          }
        }
      ],

      # Row 3: Failures
      [
        {
          type   = "log"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "API Failures (incl. 429s)"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event = "api_call_failed"
              | fields @timestamp, chapter_code, model, error_class, error_message, duration_ms, http_status
              | sort @timestamp desc
              | limit 20
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "Chapter Failures"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event = "chapter_failed"
              | fields @timestamp, chapter_code, chapter_sid, error_class, error_message
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ],

      # Row 4: Reindexing
      [
        {
          type   = "log"
          x      = 0
          y      = 18
          width  = 24
          height = 6
          properties = {
            title  = "Reindex Events"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "self_text_generator" and event in ["reindex_started", "reindex_completed"]
              | fields @timestamp, event
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ]
    )
  })
}
