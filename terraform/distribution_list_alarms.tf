# Alerts when the backend cannot read an email distribution list (a dl-*
# Cognito group) and falls back to its env var. DistributionListRecipients logs
# distribution_list.read_failed for any AWS SDK error, for example
# AccessDeniedException when the task role is missing cognito-idp:ListUsersInGroup.
#
# The quoted term matches both the plain-text Rails log lines and the JSON
# Sidekiq log lines in the shared log group. Empty lists log
# distribution_list.fallback instead and do not alarm: that is expected while
# lists are being filled.
resource "aws_cloudwatch_log_metric_filter" "distribution_list_read_failed" {
  count = var.enable_alarms ? 1 : 0

  name           = "distribution-list-read-failed-${var.environment}"
  log_group_name = local.log_group_name
  pattern        = "\"distribution_list.read_failed\""

  metric_transformation {
    name      = "DistributionListReadFailedCount"
    namespace = "TradeTariff/DistributionLists"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "distribution_list_read_failed" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "distribution-list-read-failed-${var.environment}"
  alarm_description   = "The backend could not read an email distribution list from Cognito in ${var.environment}, so the email went to its fallback env var (or nowhere if that is unset). First action: search ${local.log_group_name} for distribution_list.read_failed; group= names the list and reason= the AWS error class. AccessDeniedException usually means the task role lacks cognito-idp:ListUsersInGroup: check COGNITO_USER_POOL_ID is in the worker and backend-job secrets and terraform/iam.tf has been applied. See docs/email-distribution-lists.md."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"

  namespace   = "TradeTariff/DistributionLists"
  metric_name = aws_cloudwatch_log_metric_filter.distribution_list_read_failed[0].metric_transformation[0].name
  statistic   = "Sum"
  period      = 300
  unit        = "Count"

  alarm_actions = [data.aws_sns_topic.slack_topic.arn]
  ok_actions    = [data.aws_sns_topic.slack_topic.arn]
}
