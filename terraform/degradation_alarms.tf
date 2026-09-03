locals {
  log_group_name = "platform-logs-${var.environment}"

  # Metric filters match the JSON lines already emitted in production:
  # - Lograge Logstash request logs (status + controller)
  # - Search::Logger / TariffSynchronizer::SyncLogger structured events
  # - CustomJobLogger failures wrapped by Sidekiq's JSON formatter (msg.status)
  degradation_log_alarms = {
    http_5xx = {
      filter_name         = "backend-http-5xx-${var.environment}"
      pattern             = "{ $.status >= 500 && $.controller = * }"
      metric_name         = "Http5xxCount"
      alarm_name          = "backend-http-5xx-${var.environment}"
      alarm_description   = "Backend HTTP 5xx responses in ${var.environment} exceeded the log-volume threshold. Owner: Trade Tariff backend. First action: CloudWatch log group ${local.log_group_name} filtered by status>=500."
      threshold           = 10
      period              = 60
      evaluation_periods  = 5
      datapoints_to_alarm = 3
    }
    search_failed = {
      filter_name         = "backend-search-failed-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"search_failed\" }"
      metric_name         = "SearchFailedCount"
      alarm_name          = "backend-search-failed-${var.environment}"
      alarm_description   = "Search is failing in ${var.environment}. Owner: Trade Tariff backend. First action: Search dashboard Search-${var.environment} and logs in ${local.log_group_name} with service=search event=search_failed."
      threshold           = 5
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    tariff_sync_run_failed = {
      filter_name         = "backend-tariff-sync-run-failed-${var.environment}"
      pattern             = "{ $.service = \"tariff_sync\" && $.event = \"sync_run_failed\" }"
      metric_name         = "TariffSyncRunFailedCount"
      alarm_name          = "backend-tariff-sync-run-failed-${var.environment}"
      alarm_description   = "A CDS/TARIC sync run failed in ${var.environment}. Owner: Trade Tariff backend. First action: Tariff Sync dashboard TariffSync-${var.environment} and the admin updates UI."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    tariff_sequence_check_failed = {
      filter_name         = "backend-tariff-sequence-check-failed-${var.environment}"
      pattern             = "{ $.service = \"tariff_sync\" && $.event = \"sequence_check_failed\" }"
      metric_name         = "TariffSequenceCheckFailedCount"
      alarm_name          = "backend-tariff-sequence-check-failed-${var.environment}"
      alarm_description   = "Wrong sequence between pending and applied tariff files in ${var.environment}. Owner: Trade Tariff backend. First action: admin updates UI, then Tariff Sync dashboard TariffSync-${var.environment}."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    tariff_failed_updates = {
      filter_name         = "backend-tariff-failed-updates-${var.environment}"
      pattern             = "{ $.service = \"tariff_sync\" && $.event = \"failed_updates_detected\" }"
      metric_name         = "TariffFailedUpdatesCount"
      alarm_name          = "backend-tariff-failed-updates-${var.environment}"
      alarm_description   = "Failed tariff updates were detected in ${var.environment} and will not self-recover. Owner: Trade Tariff backend. First action: admin updates UI and Tariff Sync dashboard TariffSync-${var.environment}."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    sidekiq_job_fail = {
      filter_name         = "backend-sidekiq-job-fail-${var.environment}"
      pattern             = "{ $.msg.status = \"fail\" }"
      metric_name         = "SidekiqJobFailCount"
      alarm_name          = "backend-sidekiq-job-fail-${var.environment}"
      alarm_description   = "Sidekiq jobs are failing in ${var.environment}. Owner: Trade Tariff backend. First action: Sidekiq Web UI and worker logs in ${local.log_group_name} with msg.status=fail."
      threshold           = 10
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "degradation" {
  for_each = var.enable_alarms ? local.degradation_log_alarms : {}

  name           = each.value.filter_name
  log_group_name = local.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = "TradeTariff/Backend"
    value     = "1"
    unit      = "Count"

    dimensions = {
      Environment = var.environment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "degradation" {
  for_each = var.enable_alarms ? local.degradation_log_alarms : {}

  alarm_name          = each.value.alarm_name
  alarm_description   = each.value.alarm_description
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  treat_missing_data  = "notBreaching"

  namespace   = "TradeTariff/Backend"
  metric_name = each.value.metric_name
  statistic   = "Sum"
  period      = each.value.period
  unit        = "Count"

  dimensions = {
    Environment = var.environment
  }

  alarm_actions = [data.aws_sns_topic.slack_topic.arn]
  ok_actions    = [data.aws_sns_topic.slack_topic.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.degradation]
}
