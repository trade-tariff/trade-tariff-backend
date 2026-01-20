output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.label_generator.dashboard_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.label_generator.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${local.dashboard_name}"
}

output "metric_namespace" {
  description = "CloudWatch metric namespace for label generator metrics"
  value       = "LabelGenerator/${var.environment}"
}

output "alarm_arns" {
  description = "ARNs of the CloudWatch alarms (if created)"
  value = var.alarm_sns_topic_arn != null ? {
    api_failures     = aws_cloudwatch_metric_alarm.api_failures[0].arn
    page_failures    = aws_cloudwatch_metric_alarm.page_failures[0].arn
    high_api_latency = aws_cloudwatch_metric_alarm.high_api_latency[0].arn
    no_labels        = aws_cloudwatch_metric_alarm.no_labels_created[0].arn
  } : {}
}
