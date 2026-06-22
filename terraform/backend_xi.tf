module "backend_xi" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v3.2.0"

  region = var.region

  service_name              = "backend-xi"
  container_definition_kind = "web"
  service_count             = var.service_count

  cluster_name    = "trade-tariff-cluster-${var.environment}"
  subnet_ids      = data.aws_subnets.private.ids
  security_groups = [data.aws_security_group.this.id]

  target_group_arn = data.aws_lb_target_group.backend_xi_https.arn
  container_port   = 8443

  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  skip_destroy = true

  private_dns_namespace = "tariff.internal"

  cpu    = var.cpu
  memory = var.memory

  task_role_policy_arns = [aws_iam_policy.task.arn]

  service_environment_config = local.backend_xi_service_env_vars

  enable_ecs_exec = true

  has_autoscaler     = local.has_autoscaler
  min_capacity       = var.backend_xi_min_capacity
  max_capacity       = var.max_capacity
  scale_in_cooldown  = var.scale_in_cooldown
  scale_out_cooldown = var.scale_out_cooldown

  autoscaling_metrics = {
    cpu = {
      metric_type  = "ECSServiceAverageCPUUtilization"
      target_value = 30
    }
    memory = {
      metric_type  = "ECSServiceAverageMemoryUtilization"
      target_value = 70
    }
  }

  enable_alarms       = var.enable_alarms
  cpu_alarm_threshold = 85 # Temporarily set higher to avoid alarm noise during load testing, will be adjusted based on observed metrics after testing is complete.

  sns_topic_arns               = [data.aws_sns_topic.slack_topic.arn]
  observability_sns_topic_arns = var.enable_observability_alerts ? [data.aws_sns_topic.slack_observability_topic[0].arn] : null
}
