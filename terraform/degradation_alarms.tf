locals {
  log_group_name              = "platform-logs-${var.environment}"
  search_operations_dashboard = "SearchOperations-${var.environment}"

  # One CloudWatch alarm per search component so a widespread outage pages once.
  search_degradation_alarms = {
    opensearch = {
      filter_name         = "search-opensearch-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"retrieval_leg_completed\" && $.leg = \"opensearch\" && $.status = \"error\" }"
      metric_name         = "SearchOpensearchErrorCount"
      alarm_name          = "search-opensearch-error-${var.environment}"
      alarm_description   = "OpenSearch retrieval failed for AI-assisted search in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard} Hybrid Leg Failures, then ${local.log_group_name} filtered by service=search event=retrieval_leg_completed leg=opensearch status=error — use request_id and error_message to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    embedding = {
      filter_name         = "search-embedding-error-${var.environment}"
      pattern             = "{ $.service = \"ai_usage\" && $.event = \"embedding_api_call_failed\" && $.event_kind = \"vector_search_query_embedding\" }"
      metric_name         = "SearchEmbeddingErrorCount"
      alarm_name          = "search-embedding-error-${var.environment}"
      alarm_description   = "Query embedding calls failed for AI-assisted search in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=ai_usage event=embedding_api_call_failed event_kind=vector_search_query_embedding — use request_id, error_class, and error_message to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    llm = {
      filter_name         = "search-llm-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.event = \"api_call_completed\" && $.response_type = \"error\" }"
      metric_name         = "SearchLlmErrorCount"
      alarm_name          = "search-llm-error-${var.environment}"
      alarm_description   = "LLM calls failed for AI-assisted search in ${var.environment} (interactive search, query expansion, or duplicate-question validation). Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search event=api_call_completed response_type=error — use request_id, operation, and error_message to diagnose."
      threshold           = 0
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
