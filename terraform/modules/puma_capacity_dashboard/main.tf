locals {
  puma_worker_charts = [
    { title = "Busiest worker utilisation (%)", metric = "Utilization", stat = "Maximum" },
    { title = "Available threads per worker (minimum)", metric = "AvailableThreads", stat = "Minimum" },
    { title = "Busy threads per worker (maximum)", metric = "BusyThreads", stat = "Maximum" },
    { title = "Queued requests per worker (maximum)", metric = "Backlog", stat = "Maximum" },
    { title = "Peak backlog since previous stats read", metric = "BacklogMax", stat = "Maximum" },
    { title = "Stale workers per task (maximum)", metric = "StaleWorkers", stat = "Maximum" },
  ]
}

resource "aws_cloudwatch_dashboard" "puma_capacity" {
  dashboard_name = "Puma-${var.application}-${var.environment}"
  dashboard_body = jsonencode({
    start          = "-PT3H"
    periodOverride = "inherit"
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 3
        properties = {
          markdown = "# Puma request capacity\n10-second snapshots; worker check-ins can lag. These are thread-pool queues, NOT queue waiting time or Sidekiq. Never sum gauge samples over time. Missing/stale telemetry is NOT spare capacity. Fleet totals below include only reporting workers: check coverage before interpreting them. Task turnover and sampling boundaries can temporarily distort fleet totals. High-resolution metrics retain sub-minute detail for 3 hours; use 60s/300s periods for week/month views."
        }
      }
      ], flatten([
        for service_index, service in var.services : concat([
          for chart_index, chart in local.puma_worker_charts : {
            type = "metric", x = (chart_index % 3) * 8, y = 3 + service_index * 24 + floor(chart_index / 3) * 6, width = 8, height = 6
            properties = {
              title   = "${service}: ${chart.title}", region = var.region, view = "timeSeries", period = 60
              metrics = [["TradeTariff/Puma", chart.metric, "Environment", var.environment, "Service", service, { stat = chart.stat }]]
            }
          }
          ], [
          {
            type = "log", x = 0, y = 15 + service_index * 24, width = 12, height = 6
            properties = {
              title = "${service}: sampled fleet slots (reporting workers only)", region = var.region, view = "timeSeries"
              query = <<-QUERY
              SOURCE 'platform-logs-${var.environment}'
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | stats latest(task_busy_threads) as busy, latest(task_available_threads) as available, latest(task_backlog) as queued by collector_id, bin(10s) as sampled_at
              | stats sum(busy) as busy_threads, sum(available) as available_threads, sum(queued) as backlog by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "log", x = 12, y = 15 + service_index * 24, width = 12, height = 6
            properties = {
              title = "${service}: reporting coverage (compare with running tasks)", region = var.region, view = "timeSeries"
              query = <<-QUERY
              SOURCE 'platform-logs-${var.environment}'
              | filter event = "puma.metrics" and Service = "${service}" and Environment = "${var.environment}"
              | stats latest(ReportingWorkers) as reporting, latest(ExpectedWorkers) as expected, latest(StaleWorkers) as stale, latest(UnreadyWorkers) as unready by collector_id, bin(10s) as sampled_at
              | stats count(*) as reporting_tasks, sum(reporting) as reporting_workers, sum(expected) as expected_workers, sum(stale) as stale_workers, sum(unready) as unready_workers by sampled_at
              | sort sampled_at asc
            QUERY
            }
          },
          {
            type = "metric", x = 0, y = 21 + service_index * 24, width = 12, height = 6
            properties = {
              title = "${service}: running and desired ECS tasks", region = var.region, view = "timeSeries", period = 60
              metrics = [
                ["ECS/ContainerInsights", "RunningTaskCount", "ServiceName", service, "ClusterName", "trade-tariff-cluster-${var.environment}", { stat = "Minimum" }],
                ["ECS/ContainerInsights", "DesiredTaskCount", "ServiceName", service, "ClusterName", "trade-tariff-cluster-${var.environment}", { stat = "Maximum" }],
              ]
            }
          },
          {
            type = "metric", x = 12, y = 21 + service_index * 24, width = 12, height = 6
            properties = {
              title = "${service}: fully occupied / unready workers per task (maximum)", region = var.region, view = "timeSeries", period = 60
              metrics = [
                ["TradeTariff/Puma", "SaturatedWorkers", "Environment", var.environment, "Service", service, { stat = "Maximum" }],
                ["TradeTariff/Puma", "UnreadyWorkers", "Environment", var.environment, "Service", service, { stat = "Maximum" }],
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
