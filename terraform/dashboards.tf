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
