locals {
  ai_cost_events = "filter event in [\"api_call_completed\", \"embedding_api_call_completed\", \"api_call_failed\", \"embedding_api_call_failed\"] and ispresent(event_kind)"
}

resource "aws_cloudwatch_dashboard" "ai_costs" {
  dashboard_name = "AICosts-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "log", x = 0, y = 0, width = 12, height = 6
        properties = {
          title = "Total Cost by Event Kind", region = var.region, view = "bar"
          query = "SOURCE 'platform-logs-${var.environment}' | ${local.ai_cost_events} | filter pricing_known = true | stats sum(total_cost_usd) as total_cost_usd by event_kind | sort total_cost_usd desc"
        }
      },
      {
        type = "log", x = 12, y = 0, width = 12, height = 6
        properties = {
          title = "Token Totals by Event Kind", region = var.region, view = "bar"
          query = "SOURCE 'platform-logs-${var.environment}' | ${local.ai_cost_events} | stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(total_tokens) as total_tokens by event_kind | sort total_tokens desc"
        }
      },
      {
        type = "log", x = 0, y = 6, width = 24, height = 8
        properties = {
          title = "Unknown or High-Cost Events", region = var.region
          query = "SOURCE 'platform-logs-${var.environment}' | ${local.ai_cost_events} | fields @timestamp, service, event, event_kind, model, total_tokens, total_cost_usd, pricing_known | filter pricing_known = false or not ispresent(total_cost_usd) or total_cost_usd > 0 | sort total_cost_usd desc, total_tokens desc | limit 50"
        }
      },
    ]
  })
}

module "label_generator_dashboard" {
  source = "./modules/label_generator_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "label_generator_dashboard_url" {
  description = "URL to the Label Generator CloudWatch dashboard"
  value       = module.label_generator_dashboard.dashboard_url
}

module "search_dashboard" {
  source = "./modules/search_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "search_dashboard_url" {
  description = "URL to the Search CloudWatch dashboard"
  value       = module.search_dashboard.dashboard_url
}

module "search_operations_dashboard" {
  source = "./modules/search_operations_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "search_operations_dashboard_url" {
  description = "URL to the Search Operations CloudWatch dashboard"
  value       = module.search_operations_dashboard.dashboard_url
}

module "search_quality_dashboard" {
  source = "./modules/search_quality_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "search_quality_dashboard_url" {
  description = "URL to the Search Quality CloudWatch dashboard"
  value       = module.search_quality_dashboard.dashboard_url
}

module "self_text_generator_dashboard" {
  source = "./modules/self_text_generator_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "self_text_generator_dashboard_url" {
  description = "URL to the Self-Text Generator CloudWatch dashboard"
  value       = module.self_text_generator_dashboard.dashboard_url
}

module "tariff_sync_dashboard" {
  source = "./modules/tariff_sync_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "tariff_sync_dashboard_url" {
  description = "URL to the Tariff Sync CloudWatch dashboard"
  value       = module.tariff_sync_dashboard.dashboard_url
}

module "tariff_note_pipeline_dashboard" {
  source = "./modules/tariff_note_pipeline_dashboard"

  environment    = var.environment
  log_group_name = "platform-logs-${var.environment}"
  region         = var.region
}

output "tariff_note_pipeline_dashboard_url" {
  description = "URL to the Tariff Note Pipeline CloudWatch dashboard"
  value       = module.tariff_note_pipeline_dashboard.dashboard_url
}
