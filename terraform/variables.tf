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

variable "backend_uk_min_capacity" {
  description = "Smallest number of tasks the backend-uk service can scale-in to."
  type        = number
  default     = 1
}

variable "backend_xi_min_capacity" {
  description = "Smallest number of tasks the backend-xi service can scale-in to."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Largest number of tasks the service can scale-out to."
  type        = number
  default     = 5
}

variable "cpu" {
  description = "CPU units to use."
  type        = number
}

variable "memory" {
  description = "Memory to allocate in MB. Powers of 2 only."
  type        = number
}

variable "enable_alarms" {
  description = "Whether to enable CloudWatch alarms for the service."
  type        = bool
  default     = false
}

variable "enable_database_replication" {
  description = "Whether to enable the scheduled database replication job."
  type        = bool
  default     = false
}

variable "enable_observability_alerts" {
  type    = bool
  default = false
}

variable "scale_in_cooldown" {
  description = "Prevents aggressive scale-in by enforcing a waiting period after tasks are removed."
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Minimum time to wait after a scale-out before allowing another scale-out, giving new tasks time to start contributing capacity."
  type        = number
  default     = 60
}

variable "backend_uk_scheduled_scaling_actions" {
  description = <<EOT
Map of scheduled scaling actions keyed by a unique name. Each value must include:
- schedule     : AWS cron expression in UTC, e.g. 'cron(0 7 ? * MON-FRI *)'
- min_capacity : minimum desired tasks at schedule time
- max_capacity : maximum desired tasks at schedule time
EOT
  type = map(object({
    schedule     = string
    min_capacity = number
    max_capacity = number
  }))
  default = {}
  validation {
    condition = alltrue([
      for _, action in var.backend_uk_scheduled_scaling_actions :
      action.min_capacity >= 0 && action.max_capacity >= 0 && action.min_capacity <= action.max_capacity
    ])
    error_message = "Each backend_uk_scheduled_scaling_actions entry must have non-negative min_capacity/max_capacity and min_capacity must be <= max_capacity."
  }
}
