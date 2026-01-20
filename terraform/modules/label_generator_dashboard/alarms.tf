# Alarms (only created if SNS topic is provided)

resource "aws_cloudwatch_metric_alarm" "api_failures" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "label-generator-api-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LabelGeneratorAPIFailures"
  namespace           = "LabelGenerator/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_error_threshold
  alarm_description   = "Label Generator API failures exceeded threshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = {
    Environment = var.environment
    Service     = "label-generator"
  }
}

resource "aws_cloudwatch_metric_alarm" "page_failures" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "label-generator-page-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LabelGeneratorPageFailures"
  namespace           = "LabelGenerator/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = var.page_error_threshold
  alarm_description   = "Label Generator page processing failures exceeded threshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = {
    Environment = var.environment
    Service     = "label-generator"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_api_latency" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "label-generator-high-api-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "LabelGeneratorAPILatency"
  namespace           = "LabelGenerator/${var.environment}"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 30000 # 30 seconds
  alarm_description   = "Label Generator API latency p95 exceeded 30 seconds"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = {
    Environment = var.environment
    Service     = "label-generator"
  }
}

resource "aws_cloudwatch_metric_alarm" "no_labels_created" {
  count = var.alarm_sns_topic_arn != null ? 1 : 0

  alarm_name          = "label-generator-no-labels-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 6 # 30 minutes with no labels when generation is running
  metric_name         = "LabelGeneratorLabelsCreated"
  namespace           = "LabelGenerator/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Label Generator has not created any labels in 30 minutes"
  treat_missing_data  = "notBreaching" # Don't alarm when not running

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = {
    Environment = var.environment
    Service     = "label-generator"
  }
}
