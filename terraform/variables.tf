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
  default     = 1
}

variable "start_without_tasks" {
  description = "Create the backend and worker services with no tasks. The UAT start uses it before it restores the database, because the services cannot start on an empty database."
  type        = bool
  default     = false

  # ECS ignores later desired count changes, so only the UAT autoscaler minimum starts the tasks again.
  validation {
    condition     = !var.start_without_tasks || var.environment == "uat"
    error_message = "start_without_tasks is only for uat."
  }
}

variable "min_capacity_uk" {
  description = "Smallest number of tasks the backend-uk service can scale-in to."
  type        = number
  default     = 1
}

variable "min_capacity_xi" {
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

variable "backend_xi_scheduled_scaling_actions" {
  type = map(object({
    schedule     = string
    min_capacity = number
    max_capacity = number
  }))
  default = {}
  validation {
    condition = alltrue([
      for _, action in var.backend_xi_scheduled_scaling_actions :
      action.min_capacity >= 0 && action.max_capacity >= 0 && action.min_capacity <= action.max_capacity
    ])
    error_message = "Each backend_xi_scheduled_scaling_actions entry must have non-negative min_capacity/max_capacity and min_capacity must be <= max_capacity."
  }
}

variable "generated_secrets" {
  description = "UAT only. For each service (backend-uk, backend-xi, worker-uk, worker-xi, backend-job), environment variables mapped to the Secrets Manager secret that has the value. The common stack creates these secrets on each start. They replace the values in the configuration secret."
  type        = map(map(string))
  default     = {}
}

variable "generated_parameters" {
  description = "UAT only. For each service, environment variables mapped to the SSM parameter that has the value. The common stack creates these parameters on each start. They replace the values in the configuration secret."
  type        = map(map(string))
  default     = {}
}
