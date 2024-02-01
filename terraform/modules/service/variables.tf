variable "cpu" {
  description = "CPU limits for container."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory limits for container."
  type        = number
  default     = 512
}

variable "skip_destroy" {
  description = "(Optional) Whether to retain the old revision when the resource is destroyed or replacement is necessary. Default is false."
  type        = bool
  default     = false
}

variable "service_name" {
  description = "Name of the service to create."
  type        = string
}

variable "service_count" {
  description = "Number of replicas of the service to create. Defaults to 1."
  type        = number
  default     = 1
}

variable "deployment_maximum_percent" {
  description = "Maximum deployment as a percentage of `service_count`. Defaults to 200 for zero downtime deploys."
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percentage for a deployment. Defaults to 100 for zero downtime deploys."
  type        = number
  default     = 100
}

variable "container_port" {
  description = "Port the container should expose."
  type        = number
  default     = 80
}

variable "cluster_name" {
  description = "Name of the ECS Cluster to deploy the service into."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs to place the service into."
  type        = list(string)
}

variable "wait_for_steady_state" {
  description = "Whether to wait for the service to become stable akin to `aws ecs wait services-stable`. Defaults to true."
  type        = bool
  default     = true
}

variable "max_capacity" {
  description = "A maximum capacity for autoscaling."
  type        = number
}

variable "min_capacity" {
  description = "A minimum capacity for autoscaling. Defaults to 1."
  type        = number
  default     = 1
}

variable "autoscaling_metrics" {
  description = "A map of autoscaling metrics."
  type = map(object({
    metric_type  = string
    target_value = number
  }))
  default = {
    cpu = {
      metric_type  = "ECSServiceAverageCPUUtilization"
      target_value = 75
    },
    memory = {
      metric_type  = "ECSServiceAverageMemoryUtilization"
      target_value = 75
    }
  }
}

variable "target_group_arn" {
  description = "ARN of the load balancer target group."
  type        = string
  default     = null
}

variable "security_groups" {
  description = "A list of security group IDs to asssociate with the service."
  type        = list(string)
}

variable "timeout" {
  description = "Timeout time for the ECS service to become stable before producing a Terraform error."
  type        = string
  default     = "15m"
}

variable "private_dns_namespace" {
  description = "Private DNS namespace name. If provided, enables service discovery."
  type        = string
  default     = null
}

variable "enable_ecs_exec" {
  description = "Whether to enable AWS ECS Exec for the task. Defaults to `false`."
  type        = bool
  default     = false
}

variable "enable_rollback" {
  description = "Whether to enable circuit breaker rollbacks. Defaults to `true`."
  type        = bool
  default     = true
}

variable "container_definitions" {
  description = "Container definitions."
  type        = any
}

variable "task_role_policy_arns" {
  description = "List of additional policy ARNs to attach to the service's task role."
  type        = list(string)
  default     = []
}

variable "execution_role_policy_arns" {
  description = "List of additional policy ARNs to attach to the service's execution role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to pass in to the module resources."
  type        = map(any)
  default     = null
}
