locals {
  log_group_name              = "platform-logs-${var.environment}"
  search_operations_dashboard = "SearchOperations-${var.environment}"

  # Metric filters match JSON already emitted by Search::Logger. One CloudWatch
  # alarm per failure class so a widespread outage pages once instead of per request.
  search_degradation_alarms = {
    search_failed = {
      filter_name         = "search-failed-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"search_failed\" }"
      metric_name         = "SearchFailedCount"
      alarm_name          = "search-failed-${var.environment}"
      alarm_description   = "AI-assisted search hard-failed in ${var.environment} (OpenSearch, AI, or query expansion). Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search event=search_failed — use request_id and error_type to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    interactive_search_error = {
      filter_name         = "search-interactive-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"search_completed\" && $.final_result_type = \"error\" }"
      metric_name         = "InteractiveSearchErrorCount"
      alarm_name          = "search-interactive-error-${var.environment}"
      alarm_description   = "Interactive search completed as an error in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search event=search_completed final_result_type=error — use request_id and error_message to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    retrieval_leg_error = {
      filter_name         = "search-retrieval-leg-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"retrieval_leg_completed\" && $.status = \"error\" }"
      metric_name         = "SearchRetrievalLegErrorCount"
      alarm_name          = "search-retrieval-leg-error-${var.environment}"
      alarm_description   = "A search retrieval leg (OpenSearch or vector) failed in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard} Hybrid Leg Failures, then ${local.log_group_name} filtered by service=search event=retrieval_leg_completed status=error — use request_id, leg, and error_message to diagnose."
      threshold           = 2
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    query_expansion_timed_out = {
      filter_name         = "search-query-expansion-timed-out-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"query_expansion_timed_out\" }"
      metric_name         = "SearchQueryExpansionTimedOutCount"
      alarm_name          = "search-query-expansion-timed-out-${var.environment}"
      alarm_description   = "AI query expansion is timing out in ${var.environment} and falling back to the original query. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search event=query_expansion_timed_out — use request_id, model, and fallback_outcome to diagnose."
      threshold           = 5
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "search_degradation" {
  for_each = var.enable_alarms ? local.search_degradation_alarms : {}

  name           = each.value.filter_name
  log_group_name = local.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = "TradeTariff/Search"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "search_degradation" {
  for_each = var.enable_alarms ? local.search_degradation_alarms : {}

  alarm_name          = each.value.alarm_name
  alarm_description   = each.value.alarm_description
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  treat_missing_data  = "notBreaching"

  namespace   = "TradeTariff/Search"
  metric_name = each.value.metric_name
  statistic   = "Sum"
  period      = each.value.period
  unit        = "Count"

  alarm_actions = [data.aws_sns_topic.slack_topic.arn]
  ok_actions    = [data.aws_sns_topic.slack_topic.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.search_degradation]
}
