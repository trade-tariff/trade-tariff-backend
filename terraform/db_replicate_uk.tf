module "db-replicate-job-uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.13.1"

  service_name = "db-replicate-job-uk"
  region       = var.region

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  service_count = 1
  min_capacity  = 1
  max_capacity  = 1

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  skip_destroy = true

  cpu    = 2048
  memory = 8192

  task_role_policy_arns = [aws_iam_policy.task.arn]

  enable_ecs_exec = true

  container_command    = local.db_replicate_command

  service_environment_config = local.db_replicate_uk_secret_env_vars
}
