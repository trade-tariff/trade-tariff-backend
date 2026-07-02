region                  = "eu-west-2"
environment             = "production"
cpu                     = 2048
memory                  = 4096
service_count           = 3
backend_uk_min_capacity = 3
backend_xi_min_capacity = 2
max_capacity            = 16

enable_alarms               = true
enable_observability_alerts = true
scheduled_actions_enabled   = true

scheduled_scaling_actions = {

  midnight_scale_up = {
    schedule     = "cron(55 23 * * ? *)"
    min_capacity = 4
    max_capacity = 16
  }

  midnight_scale_down = {
    schedule     = "cron(40 0 * * ? *)"
    min_capacity = 3
    max_capacity = 16
  }

  threeam_scale_up = {
    schedule     = "cron(55 2 * * ? *)"
    min_capacity = 4
    max_capacity = 16
  }

  threeam_scale_down = {
    schedule     = "cron(40 3 * * ? *)"
    min_capacity = 3
    max_capacity = 16
  }

  fiveam_scale_up = {
    schedule     = "cron(50 4 * * ? *)"
    min_capacity = 4
    max_capacity = 16
  }

  fiveam_scale_down = {
    schedule     = "cron(0 7 * * ? *)"
    min_capacity = 3
    max_capacity = 16
  }
}
