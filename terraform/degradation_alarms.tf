locals {
  log_group_name              = "platform-logs-${var.environment}"
  search_operations_dashboard = "SearchOperations-${var.environment}"

  # Keep legacy boundary events during rolling deployments and application rollbacks.
  # These count failure events, not requests: a stage and its retrieval leg can
  # both match, but share one alarm per component.
  search_degradation_alarms = {
    opensearch = {
      filter_name         = "search-opensearch-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && (($.event = \"search_stage_failed\" && $.failure_code = \"opensearch_failed\") || ($.event = \"retrieval_leg_completed\" && $.leg = \"opensearch\" && $.status = \"error\")) }"
      metric_name         = "SearchOpensearchErrorCount"
      alarm_name          = "search-opensearch-error-${var.environment}"
      alarm_description   = "OpenSearch retrieval failed for search in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search and failure_code=opensearch_failed, or event=retrieval_leg_completed leg=opensearch status=error. Use request_id, operation, error_type, and error_message to diagnose."
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
      alarm_description   = "Query embedding calls failed or returned malformed embeddings for search in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=ai_usage event=embedding_api_call_failed event_kind=vector_search_query_embedding. Use request_id, error_class, and error_message to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    llm = {
      filter_name         = "search-llm-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && (($.event = \"api_call_completed\" && $.response_type = \"error\") || ($.event = \"search_stage_failed\" && ($.failure_code = \"query_expansion_failed\" || $.failure_code = \"interactive_search_failed\" || $.failure_code = \"duplicate_question_validation_failed\"))) }"
      metric_name         = "SearchLlmErrorCount"
      alarm_name          = "search-llm-error-${var.environment}"
      alarm_description   = "LLM calls failed or returned unusable responses for search in ${var.environment} (interactive search, query expansion, or duplicate-question validation). Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard}, then ${local.log_group_name} filtered by service=search and failure_code=query_expansion_failed, interactive_search_failed, or duplicate_question_validation_failed, or event=api_call_completed response_type=error. Use request_id, operation, error_type, and error_message to diagnose."
      threshold           = 0
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
    }
    vector = {
      filter_name         = "search-vector-error-${var.environment}"
      pattern             = "{ $.service = \"search\" && $.failure_code = \"vector_retrieval_failed\" && ($.event = \"search_stage_failed\" || ($.event = \"retrieval_leg_completed\" && $.leg = \"vector\" && $.status = \"error\")) }"
      metric_name         = "SearchVectorErrorCount"
      alarm_name          = "search-vector-error-${var.environment}"
      alarm_description   = "Vector database retrieval failed for search in ${var.environment}. Owner: Trade Tariff search. First action: dashboard ${local.search_operations_dashboard} Hybrid Leg Failures, then ${local.log_group_name} filtered by service=search failure_code=vector_retrieval_failed. Use request_id, operation, error_type, and error_message to diagnose. Embedding generation failures use the separate embedding alarm."
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

  alarm_actions = [data.aws_sns_topic.slack_observability_topic[0].arn]
  ok_actions    = [data.aws_sns_topic.slack_observability_topic[0].arn]

  depends_on = [aws_cloudwatch_log_metric_filter.search_degradation]
}
