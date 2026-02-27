locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "SelfTextGenerator-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  service_filter = "filter service = \"self_text_generator\""

  label_dashboard_url  = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  search_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "self_text_generator" {
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
              "## Self-Text Generator",
              "Batch self-text generation across 98 chapters. Each chapter runs OtherSelfTextBuilder then NonOtherSelfTextBuilder on the within_1_day queue.",
              "**Healthy:** all chapters succeed, API latency p90 < 30s, reindex completes after each batch. Scoring: mean similarity > 0.7, embedding API p90 < 5s.",
              "**Start here:** check Chapter Success vs Failure trend, then drill into failure tables and scoring metrics below.",
              "**Related:** [Label Generator](${local.label_dashboard_url}) | [Search](${local.search_dashboard_url})",
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
            title  = "Chapter Success vs Failure"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and ((event = "chapter_completed" and not ispresent(exception)) or event = "chapter_failed")
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
            title  = "Error Rate by Type"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["chapter_failed", "api_call_failed"]
              | stats count(*) as errors by event, bin(1h)
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
            title  = "Nodes Processed vs Failed"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "chapter_completed" and not ispresent(exception)
              | stats sum(ai.processed) as processed, sum(ai.failed) as failed by bin(1h)
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
            title  = "Chapter Processing Percentiles (ms)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "chapter_completed" and not ispresent(exception)
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

      # Row 3 (y=14): Generation history and reindex
      [
        {
          type   = "log"
          x      = 0
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Recent Generation Runs"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "generation_started"
              | fields @timestamp, total_chapters
              | sort @timestamp desc
              | limit 20
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
            title  = "Chapter Detail"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "chapter_completed" and not ispresent(exception)
              | fields @timestamp, chapter_code, duration_ms, mechanical.processed, ai.processed, ai.failed
              | sort @timestamp desc
              | limit 50
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
            title  = "Reindex Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["reindex_started", "reindex_completed"]
              | fields @timestamp, event
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
          width  = 12
          height = 6
          properties = {
            title  = "API Failures (incl. 429s)"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "api_call_failed"
              | fields @timestamp, chapter_code, model, error_class, error_message, duration_ms, http_status
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
            title  = "Chapter Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "chapter_failed"
              | fields @timestamp, chapter_code, chapter_sid, error_class, error_message
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ],

      # Row 5 (y=26): Confidence Scoring
      [
        {
          type   = "log"
          x      = 0
          y      = 26
          width  = 8
          height = 6
          properties = {
            title  = "Embedding API Latency (p50/p90)"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "embedding_api_call_completed"
              | stats pct(duration_ms, 50) as p50, pct(duration_ms, 90) as p90 by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 26
          width  = 8
          height = 6
          properties = {
            title  = "Similarity Score Distribution"
            region = var.region
            view   = "timeSeries"
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event = "scoring_completed" and ispresent(mean_similarity)
              | stats avg(mean_similarity) as avg_similarity, min(mean_similarity) as min_similarity by bin(1h)
            EOT
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 26
          width  = 8
          height = 6
          properties = {
            title  = "Scoring Failures"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.service_filter} and event in ["scoring_failed", "embedding_api_call_failed"]
              | fields @timestamp, chapter_code, event, error_class, error_message
              | sort @timestamp desc
              | limit 20
            EOT
          }
        }
      ]
    )
  })
}
