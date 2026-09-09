terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
  }
}

variable "environment" {
  description = "Environment dimension emitted by the reporter."
  type        = string
}

variable "region" {
  description = "Region containing the application logs and metrics."
  type        = string
}

variable "application" {
  description = "Application name used in the dashboard name."
  type        = string
}

variable "services" {
  description = "Service dimensions emitted by the reporter (frontend, backend-uk, backend-xi)."
  type        = list(string)
}
