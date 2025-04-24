module "db-replicate-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.13.1"

  region = var.region

  service_name = "db-replicate-job"
  service_count = 1

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  target_group_arn          = data.aws_lb_target_group.backend_uk.arn
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  max_capacity  = 1
  min_capacity  = 1

  docker_image    = local.ecr_repo
  docker_tag      = var.docker_tag
  cpu             = var.cpu
  memory          = var.memory

  create_job_task      = true
  container_command    = local.db_replicate_command


  service_environment_config = local.db_replicate_secret_env_vars
}
