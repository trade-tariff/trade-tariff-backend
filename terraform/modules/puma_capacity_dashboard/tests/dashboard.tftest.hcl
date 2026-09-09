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
    condition     = length(jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets) == 24
    error_message = "Both backend services must have capacity and coverage charts."
  }

  assert {
    condition = alltrue([
      for i, service in var.services :
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[1 + i * 4].properties.title == "${service}: Queued requests: busiest worker" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[2 + i * 4].properties.title == "${service}: Available threads: least spare worker" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[3 + i * 4].properties.title == "${service}: Reporting collectors: seen per minute" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[4 + i * 4].properties.title == "${service}: Running and desired ECS tasks" &&
      alltrue([for j in range(4) :
        jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[1 + i * 4 + j].x == j * 6 &&
        jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[1 + i * 4 + j].y == 4 + i * 6
      ])
    ])
    error_message = "All service summaries must align queue, spare threads, reporting collectors and ECS tasks in that order."
  }

  assert {
    condition = alltrue([
      for i in range(length(var.services)) :
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[1 + i * 4].properties.metrics[0][1] == "Backlog" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[1 + i * 4].properties.metrics[0][6].stat == "Maximum" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[2 + i * 4].properties.metrics[0][1] == "AvailableThreads" &&
      jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[2 + i * 4].properties.metrics[0][6].stat == "Minimum" &&
      can(regex("bin\\(60s\\)", jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[3 + i * 4].properties.query))
    ])
    error_message = "Summary extrema must use the correct metrics/statistics with minute-binned collector coverage."
  }

  assert {
    condition = (
      alltrue([
        for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
        !(strcontains(try(w.properties.query, ""), "sum(queued)") && strcontains(try(w.properties.query, ""), "sum(available)"))
      ]) &&
      length([for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets : w if endswith(try(w.properties.title, ""), "Queued requests: sampled service total")]) == length(var.services)
    )
    error_message = "Service queue totals must be separate from thread totals."
  }

  assert {
    condition = alltrue([
      for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
      w.properties.period == 60 && contains(["Requests", "Threads", "Tasks", "Workers", "Percent"], w.properties.yAxis.left.label)
      if w.type == "metric"
    ])
    error_message = "Metric charts must use matching minute periods and explicit operator-facing units."
  }

  assert {
    condition = alltrue([
      for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
      strcontains(w.properties.query, "filter ispresent(task_backlog)")
      if endswith(try(w.properties.title, ""), "Queued requests: sampled service total")
      ]) && alltrue([
      for w in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
      strcontains(w.properties.query, "filter ispresent(task_busy_threads)")
      if endswith(try(w.properties.title, ""), "Threads: sampled service totals")
    ])
    error_message = "Missing worker capacity must be excluded from totals, not aggregated into false zeroes."
  }

  assert {
    condition = alltrue(flatten([
      for i, a in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets : [
        for j, b in jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets :
        i == j || a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y
      ]
    ]))
    error_message = "Summary and diagnostic widgets must not overlap."
  }

  assert {
    condition = (
      can(regex("Start here", jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[0].properties.markdown)) &&
      can(regex("Missing telemetry is NOT zero", jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets[0].properties.markdown)) &&
      !can(regex("FILL\\(", aws_cloudwatch_dashboard.puma_capacity.dashboard_body))
    )
    error_message = "Start-here guidance must distinguish missing telemetry from zero without filling gaps."
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
    condition     = aws_cloudwatch_dashboard.puma_capacity.dashboard_name == "Puma-frontend-test" && length(jsondecode(aws_cloudwatch_dashboard.puma_capacity.dashboard_body).widgets) == 13
    error_message = "Frontend must have its own dashboard with one service."
  }
}
