module "db-replicate-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=HMRC-798-container-kinds"

  region = var.region

  service_name              = "db-replicate-job"
  container_definition_kind = "job"
  service_count             = 0


  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  max_capacity = 0
  min_capacity = 0

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  cpu          = var.cpu
  memory       = var.memory

  container_command = local.db_replicate_command

  service_environment_config = local.db_replicate_secret_env_vars
}
