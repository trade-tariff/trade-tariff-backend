module "backend_uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-snapshot-v1.19.3"

  region = var.region

  service_name              = "backend-uk"
  container_definition_kind = "web"
  service_count             = var.service_count

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  target_group_arn          = data.aws_lb_target_group.backend_uk.arn
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  skip_destroy = true

  container_port        = 8080
  private_dns_namespace = "tariff.internal"

  cpu    = var.cpu
  memory = var.memory

  task_role_policy_arns = [aws_iam_policy.task.arn]

  service_environment_config = local.backend_uk_secret_env_vars

  enable_ecs_exec = true

  has_autoscaler = local.has_autoscaler
  min_capacity   = var.min_capacity
  max_capacity   = var.max_capacity

  sns_topic_arns = [data.aws_sns_topic.slack_topic.arn]
}
