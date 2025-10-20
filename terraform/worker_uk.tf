module "worker_uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.18.2"

  service_name              = "worker-uk"
  container_definition_kind = "db-backed"
  region                    = var.region

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  service_count = 1

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  skip_destroy = true

  container_port        = 8080
  private_dns_namespace = "tariff.internal"

  cpu    = 2048
  memory = 4096

  task_role_policy_arns = [aws_iam_policy.task.arn]

  enable_ecs_exec = true

  container_entrypoint = [""]
  container_command    = local.worker_command

  init_container_entrypoint = [""]
  init_container_command    = local.init_command

  service_environment_config = local.worker_uk_secret_env_vars

  has_autoscaler = local.has_autoscaler
  min_capacity   = 1
  max_capacity   = var.max_capacity

  sns_topic_arns = [data.aws_sns_topic.slack_topic.arn]
}
