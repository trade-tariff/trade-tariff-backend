module "worker_xi" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v3.0.1"

  service_name = "worker-xi"
  region       = var.region

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  service_count = 1

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  skip_destroy = true

  private_dns_namespace = "tariff.internal"

  cpu    = 2048
  memory = 5120

  task_role_policy_arns = [aws_iam_policy.task.arn]

  enable_ecs_exec = true

  container_entrypoint = [""]
  container_command    = local.worker_command

  service_environment_config = local.worker_xi_secret_env_vars

  has_autoscaler     = local.has_autoscaler
  min_capacity       = 1
  max_capacity       = var.max_capacity
  scale_in_cooldown  = var.scale_in_cooldown
  scale_out_cooldown = var.scale_out_cooldown

  enable_alarms       = var.enable_alarms
  cpu_alarm_threshold = 85 # Temporarily set higher to avoid alarm noise during load testing, will be adjusted based on observed metrics after testing is complete.


  sns_topic_arns = [data.aws_sns_topic.slack_topic.arn]
}
