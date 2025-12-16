module "backend-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.18.2"

  region = var.region

  service_name              = "backend-job"
  container_definition_kind = "job"
  container_command         = local.job_command
  service_count             = 0

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  cpu          = var.cpu
  memory       = var.memory

  task_role_policy_arns = [aws_iam_policy.task.arn]

  service_environment_config = local.backend_job_secret_env_vars

  enable_ecs_exec = true

  has_autoscaler = false
  max_capacity   = 1
  min_capacity   = 0

  sns_topic_arns = [data.aws_sns_topic.slack_topic.arn]
}
