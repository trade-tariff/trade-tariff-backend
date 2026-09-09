locals {
  summary_charts = [
    { title = "Queued requests: busiest worker", metric = "Backlog", stat = "Maximum", unit = "Requests" },
    { title = "Available threads: least spare worker", metric = "AvailableThreads", stat = "Minimum", unit = "Threads" },
  ]
  worker_charts = [
    { title = "Utilisation: busiest worker (%)", metric = "Utilization", unit = "Percent" },
    { title = "Busy threads: busiest worker", metric = "BusyThreads", unit = "Threads" },
    { title = "Queued requests: peak since worker stats read", metric = "BacklogMax", unit = "Requests" },
  ]
  log_source      = "SOURCE 'platform-logs-${var.environment}'"
  detail_y        = 7 + length(var.services) * 6
  other_app       = var.application == "frontend" ? "backend" : "frontend"
  other_dashboard = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Puma-${local.other_app}-${var.environment}"
  guide_file      = var.application == "frontend" ? "puma-capacity-dashboard.md" : "puma-metrics.md"
  guide           = "https://github.com/trade-tariff/trade-tariff-${var.application}/blob/main/docs/${local.guide_file}"
}

resource "aws_cloudwatch_dashboard" "puma_capacity" {
  dashboard_name = "Puma-${var.application}-${var.environment}"
  dashboard_body = jsonencode({
    start          = "-PT3H"
    periodOverride = "inherit"
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 4
        properties = {
          markdown = join("\n\n", [
            "# Puma request capacity — ${var.environment}",
            "**Start here:** compare queued requests and spare threads, then reporting collectors against ECS tasks. Check worker coverage below before trusting spare capacity. An empty internal queue does not prove service health.",
            "**Missing telemetry is NOT zero or spare capacity.** Collectors seen per minute are a task-coverage proxy, not a concurrent task count; restart/rollout overlap can inflate it. Extrema may come from different workers and times.",
            "[${local.other_app} dashboard](${local.other_dashboard}) | [Investigation and rollout guide](${local.guide})",
          ])
        }
      }
      ], flatten([
        for service_index, service in var.services : concat([
          for chart_index, chart in local.summary_charts : {
            type = "metric", x = chart_index * 6, y = 4 + service_index * 6, width = 6, height = 6
            properties = {
              title   = "${service}: ${chart.title}", region = var.region, view = "timeSeries", period = 60
              yAxis   = { left = { label = chart.unit, showUnits = false, min = 0 } }
              metrics = [["TradeTariff/Puma", chart.metric, "Environment", var.environment, "Service", service, { stat = chart.stat }]]
            }
          }
          ], [
          {
            type = "log", x = 12, y = 4 + service_index * 6, width = 6, height = 6
            properties = {
              title = "${service}: Reporting collectors: seen per minute", region = var.region, view = "timeSeries"
              query = <<-QUERY
              ${local.log_source}
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | stats latest(ReportingWorkers) as reporting by collector_id, bin(60s) as sampled_at
              | stats count(*) as reporting_collectors by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "metric", x = 18, y = 4 + service_index * 6, width = 6, height = 6
            properties = {
              title = "${service}: Running and desired ECS tasks", region = var.region, view = "timeSeries", period = 60
              yAxis = { left = { label = "Tasks", showUnits = false, min = 0 } }
              metrics = [
                ["ECS/ContainerInsights", "RunningTaskCount", "ServiceName", service, "ClusterName", "trade-tariff-cluster-${var.environment}", { stat = "Minimum", label = "Running tasks: minimum" }],
                ["ECS/ContainerInsights", "DesiredTaskCount", "ServiceName", service, "ClusterName", "trade-tariff-cluster-${var.environment}", { stat = "Maximum", label = "Desired tasks: maximum" }],
              ]
            }
          },
        ])
      ]), [
      {
        type = "text", x = 0, y = local.detail_y - 3, width = 24, height = 3
        properties = {
          markdown = "## Diagnostic detail\nService totals include reporting workers only; compare reporting with expected workers and stale/unready counts. Gauges must not be summed over time. Summary charts use 60s periods/bins; diagnostic log charts use 10s bins and incur query costs. Use short windows; see the [guide](${local.guide}) for longer-term analysis. Puma queues exclude socket/network waits and Sidekiq."
        }
      }
      ], flatten([
        for service_index, service in var.services : concat([
          for chart_index, chart in local.worker_charts : {
            type = "metric", x = chart_index * 8, y = local.detail_y + service_index * 18, width = 8, height = 6
            properties = {
              title   = "${service}: ${chart.title}", region = var.region, view = "timeSeries", period = 60
              yAxis   = { left = { label = chart.unit, showUnits = false, min = 0 } }
              metrics = [["TradeTariff/Puma", chart.metric, "Environment", var.environment, "Service", service, { stat = "Maximum" }]]
            }
          }
          ], [
          {
            type = "log", x = 0, y = local.detail_y + 6 + service_index * 18, width = 12, height = 6
            properties = {
              title = "${service}: Threads: sampled service totals", region = var.region, view = "timeSeries"
              query = <<-QUERY
              ${local.log_source}
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | filter ispresent(task_busy_threads)
              | stats latest(task_busy_threads) as busy, latest(task_available_threads) as available by collector_id, bin(10s) as sampled_at
              | stats sum(busy) as busy_threads, sum(available) as available_threads by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "log", x = 12, y = local.detail_y + 6 + service_index * 18, width = 12, height = 6
            properties = {
              title = "${service}: Queued requests: sampled service total", region = var.region, view = "timeSeries"
              query = <<-QUERY
              ${local.log_source}
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | filter ispresent(task_backlog)
              | stats latest(task_backlog) as queued by collector_id, bin(10s) as sampled_at
              | stats sum(queued) as queued_requests by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "log", x = 0, y = local.detail_y + 12 + service_index * 18, width = 12, height = 6
            properties = {
              title = "${service}: Workers: sampled reporting coverage", region = var.region, view = "timeSeries"
              query = <<-QUERY
              ${local.log_source}
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | stats latest(ReportingWorkers) as reporting, latest(ExpectedWorkers) as expected, latest(StaleWorkers) as stale, latest(UnreadyWorkers) as unready by collector_id, bin(10s) as sampled_at
              | stats sum(reporting) as reporting_workers, sum(expected) as expected_workers, sum(stale) as stale_workers, sum(unready) as unready_workers by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "metric", x = 12, y = local.detail_y + 12 + service_index * 18, width = 12, height = 6
            properties = {
              title = "${service}: Workers per task: maximum stale, unready or occupied", region = var.region, view = "timeSeries", period = 60
              yAxis = { left = { label = "Workers", showUnits = false, min = 0 } }
              metrics = [
                for metric in ["StaleWorkers", "UnreadyWorkers", "SaturatedWorkers"] :
                ["TradeTariff/Puma", metric, "Environment", var.environment, "Service", service, { stat = "Maximum" }]
              ]
            }
          },
        ])
    ]))
  })
}

output "puma_capacity_dashboard_name" {
  description = "Puma capacity dashboard (metrics require manual enablement through the application configuration secret)."
  value       = aws_cloudwatch_dashboard.puma_capacity.dashboard_name
}
