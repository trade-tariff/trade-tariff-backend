locals {
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "AICosts-${var.environment}"
  source         = "SOURCE '${var.log_group_name}'"
  ai_cost_events = "filter event in [\"api_call_completed\", \"embedding_api_call_completed\", \"api_call_failed\", \"embedding_api_call_failed\"] and ispresent(event_kind)"

  search_dashboard_url    = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Search-${var.environment}"
  label_dashboard_url     = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=LabelGenerator-${var.environment}"
  self_text_dashboard_url = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=SelfTextGenerator-${var.environment}"
}

resource "aws_cloudwatch_dashboard" "ai_costs" {
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
              "## AI Costs",
              "CloudWatch Logs Insights dashboard for OpenAI token usage and estimated USD cost.",
              "**Start here:** use Total Cost by Event Kind for the selected time window, then inspect token volume and unknown pricing rows.",
              "**Related:** [Search](${local.search_dashboard_url}) | [Label Generator](${local.label_dashboard_url}) | [Self-Text Generator](${local.self_text_dashboard_url})",
            ])
          }
        }
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 2
          width  = 12
          height = 6
          properties = {
            title  = "Total Cost by Event Kind"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_events}
              | filter pricing_known = true and ispresent(total_cost_usd)
              | stats sum(total_cost_usd) as total_cost_usd by event_kind
              | sort total_cost_usd desc
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 2
          width  = 12
          height = 6
          properties = {
            title  = "Token Totals by Event Kind"
            region = var.region
            view   = "bar"
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_events}
              | stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(total_tokens) as total_tokens by event_kind
              | sort total_tokens desc
            EOT
          }
        }
      ],
      [
        {
          type   = "log"
          x      = 0
          y      = 8
          width  = 12
          height = 7
          properties = {
            title  = "Unknown Pricing Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_events}
              | filter pricing_known = false or not ispresent(total_cost_usd)
              | stats count(*) as events, sum(total_tokens) as total_tokens, sum(total_cost_usd) as partial_cost_usd by event_kind, model
              | sort events desc, partial_cost_usd desc, total_tokens desc
              | limit 50
            EOT
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 8
          width  = 12
          height = 7
          properties = {
            title  = "Recent Costed AI Events"
            region = var.region
            query  = <<-EOT
              ${local.source}
              | ${local.ai_cost_events}
              | filter ispresent(total_cost_usd)
              | fields @timestamp, service, event, event_kind, model, input_tokens, output_tokens, total_tokens, total_cost_usd, pricing_known
              | sort @timestamp desc
              | limit 50
            EOT
          }
        }
      ]
    )
  })
}
