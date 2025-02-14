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
  description = "Host address of the service."
  type        = string
}

variable "frontend_base_domain" {
  description = "Host address of the frontend service."
  type        = string
}

variable "alcohol_coercian_starts_from" {
  description = "When alcohol measurement unit coercian starts from for excise measurement units"
  type        = string
  default     = "2023-01-01"
}

variable "cpu" {
  description = "CPU units to use."
  type        = number
}

variable "memory" {
  description = "Memory to allocate in MB. Powers of 2 only."
  type        = number
}

variable "stemming_exclusion_reference_analyzer" {
  description = "Stemmer package file path in opensearch"
  type        = string
}

variable "synonym_reference_analyzer" {
  description = "Synonym package file path in opensearch"
  type        = string
}

variable "management_email" {
  description = "Email address for the exchange rate management team."
  type        = string
}

variable "legacy_search_enhancements_enabled" {
  description = "Enable legacy search enhancements"
  type        = bool
}

variable "green_lanes_update_email" {
  description = "Email address for the green lanes policy team."
  type        = string
}

variable "green_lanes_notify_measure_updates" {
  description = "Flag to indicate if updated or expired measure records should be included in green lanes update email."
  type        = bool
}

variable "optimised_search_enabled" {
  description = "Flag to indicate if OTT search use the new elastic search index for search and suggestions"
  type        = bool
}

variable "disable_admin_api_authentication" {
  description = "Flag to indicate if admin API authentication should be disabled."
  type        = bool
  default     = false
}
