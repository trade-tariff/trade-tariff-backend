# Reporter enablement is managed manually through application configuration
# secrets. This module creates a dashboard only; it does not change ECS tasks.
module "puma_capacity_dashboard" {
  source      = "./modules/puma_capacity_dashboard"
  environment = var.environment
  region      = var.region
  application = "backend"
  services    = ["backend-uk", "backend-xi"]
}

output "puma_capacity_dashboard_name" {
  description = "Dashboard for Puma web request capacity."
  value       = module.puma_capacity_dashboard.puma_capacity_dashboard_name
}
