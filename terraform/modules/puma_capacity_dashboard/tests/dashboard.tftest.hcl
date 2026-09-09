mock_provider "aws" {}

variables {
  environment = "test"
  region      = "eu-west-2"
  application = "backend"
  services    = ["backend-uk", "backend-xi"]
}

run "backend_dashboard" {
  command = plan

  assert {
    condition     = aws_cloudwatch_dashboard.puma_capacity.dashboard_name == "Puma-backend-test"
    error_message = "Backend dashboard must have a unique environment-specific name."
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets) == 21
    error_message = "Both backend services must have capacity and coverage charts."
  }

  assert {
    condition = alltrue(flatten([
      for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets : [
        for metric in try(w.properties.metrics, []) :
        contains(["Minimum", "Maximum", "Average"], metric[length(metric) - 1].stat)
      ]
    ]))
    error_message = "Gauge metrics must not sum samples over time."
  }

  assert {
    condition = alltrue([
      for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
      can(regex("latest\\(", w.properties.query)) && can(regex("collector_id", w.properties.query))
      if w.type == "log"
    ])
    error_message = "Fleet charts must deduplicate snapshots by collector before summing."
  }
}

run "frontend_dashboard" {
  command = plan
  variables {
    application = "frontend"
    services    = ["frontend"]
  }

  assert {
    condition     = aws_cloudwatch_dashboard.puma_capacity.dashboard_name == "Puma-frontend-test" && length(jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets) == 11
    error_message = "Frontend must have its own dashboard with one service."
  }
}
