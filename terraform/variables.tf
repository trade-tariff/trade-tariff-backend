variable "tariff_backend_sentry_dsn" {
  description = "Backend Sentry DSN."
  type        = string
  sensitive   = true
}

variable "tariff_backend_sync_email" {
  description = "Tariff Sync email."
  type        = string
  sensitive   = true
}

variable "tariff_backend_sync_host" {
  description = "Tariff Sync host."
  type        = string
  sensitive   = true
}

variable "tariff_backend_sync_password" {
  description = "Tariff Sync password."
  type        = string
  sensitive   = true
}

variable "tariff_backend_sync_username" {
  description = "Tariff Sync username."
  type        = string
  sensitive   = true
}

variable "tariff_backend_oauth_id" {
  description = "Tariff Backend OAuth ID."
  type        = string
  sensitive   = true
}

variable "tariff_backend_oauth_secret" {
  description = "Tariff Backend OAuth secret."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "region" {
  description = "AWS region to use."
  type        = string
}

variable "docker_tag" {
  description = "Image tag to use."
  type        = string
}

variable "service_count" {
  description = "Number of services to use."
  type        = number
  default     = 2
}

variable "service_name" {
  description = "Name of the service"
  type        = string
  default     = "backend"
}

variable "min_capacity" {
  description = "Smallest number of tasks the service can scale-in to."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Largest number of tasks the service can scale-out to."
  type        = number
  default     = 5
}

variable "base_domain" {
  description = "URL of the service."
  type        = string
}

variable "trade_tariff_oauth_secret" {
  description = "trade tarrif oauth secrets."
  type        = "map"
}
