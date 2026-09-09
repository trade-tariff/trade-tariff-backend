output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.search_experiment.dashboard_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.search_experiment.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${local.dashboard_name}"
}

output "queries" {
  description = "Rendered queries and languages for read-only validation"
  value = { for widget in local.dashboard_body.widgets : widget.properties.title => {
    query_string = widget.properties.query, query_language = lookup(widget.properties, "queryLanguage", "CWLI")
  } if widget.type == "log" }
}
