variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Log Group name where self-text generator logs are sent"
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
