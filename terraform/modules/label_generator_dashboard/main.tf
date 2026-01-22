locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "LabelGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "label_generator" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
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
              | fields @timestamp, total_pages, duration_ms
              | filter service = "label_generator" and event = "generation_completed"
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
            title  = "Page Success/Failure"
            region = var.region
            query  = "SOURCE '${var.log_group_name}' | filter service = 'label_generator' and event in ['page_completed', 'page_failed'] | stats count(*) as count by event"
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
              | filter service = "label_generator" and event in ["page_failed", "api_call_failed", "label_save_failed"]
              | stats count(*) as count by event, error_class
              | sort count desc
            EOT
          }
        }
      ],

      # Row 2: Processing metrics
      [
        {
          type   = "log"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "Page Processing Times (ms)"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "page_completed"
              | fields @timestamp, page_number, duration_ms, labels_created, labels_failed
              | sort @timestamp desc
              | limit 50
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
            title  = "API Latency (ms)"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "api_call_completed"
              | fields @timestamp, duration_ms, page_number
              | sort @timestamp desc
              | limit 50
            EOT
          }
        }
      ],

      # Row 3: Mismatches
      [
        {
          type   = "log"
          x      = 0
          y      = 12
          width  = 24
          height = 6
          properties = {
            title  = "AI Result Mismatches"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "api_call_completed" and batch_size != results_count
              | fields @timestamp, page_number, batch_size, results_count, model
              | sort @timestamp desc
              | limit 50
            EOT
          }
        }
      ],

      # Row 4: Errors and Failures
      [
        {
          type   = "log"
          x      = 0
          y      = 18
          width  = 8
          height = 6
          properties = {
            title  = "API Failures"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "api_call_failed"
              | fields @timestamp, page_number, model, error_class, error_message, duration_ms
              | sort @timestamp desc
              | limit 20
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
            title  = "Page Failures"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "page_failed"
              | fields @timestamp, page_number, error_class, error_message, ai_response
              | sort @timestamp desc
              | limit 20
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
            title  = "Label Save Failures"
            region = var.region
            query  = <<-EOT
              SOURCE '${var.log_group_name}'
              | filter service = "label_generator" and event = "label_save_failed"
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
