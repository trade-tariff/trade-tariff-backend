module "db-replicate-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.13.1"

  service_name = "db-replicate-job"
  region       = var.region

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  service_count = 0
  max_capacity  = 1

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
}
