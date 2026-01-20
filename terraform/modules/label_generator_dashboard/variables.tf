variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Log Group name where label generator logs are sent"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  type        = string
  default     = null
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications (optional)"
  type        = string
  default     = null
}

variable "api_error_threshold" {
  description = "Number of API failures before alarming"
  type        = number
  default     = 5
}

variable "page_error_threshold" {
  description = "Number of page failures before alarming"
  type        = number
  default     = 3
}
