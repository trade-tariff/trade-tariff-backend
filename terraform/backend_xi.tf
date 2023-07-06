module "backend_xi" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.2.0"

  service_name  = var.service_name
  service_count = var.service_count
  environment   = var.environment
  region        = var.region

  cluster_name     = "trade-tariff-cluster-${var.environment}"
  subnet_ids       = data.aws_subnets.private.ids
  security_groups  = [data.aws_security_group.this.arn]
  target_group_arn = data.aws_lb_target_group.this.arn

  min_capacity = var.min_capacity
  max_capacity = var.max_capacity
  docker_image = data.aws_ssm_parameter.ecr_url.value
  docker_tag   = var.docker_tag
  skip_destroy = true

  # backend_xi_vars
  service_environment_config = [
    {
      name  = "/${var.environment}/backend/xi/CDS"
      value = "false"
    },
    {
      name  = "/${var.environment}/backend/xi/GOVUK_APP_DOMAIN"
      value = "tariff-xi-backend-${local.environment_key}.apps.internal"
    },
    {
      name  = "/${var.environment}/backend/xi/NEW_RELIC_APP_NAME"
      value = "tariff-xi-backend-${var.environment}"
    },
    {
      name  = "/${var.environment}/backend/xi/SERVICE"
      value = "xi"
    },
    {
      name  = "/${var.environment}/backend/xi/TARIFF_FROM_EMAIL"
      value = "Tariff XI [${upper(var.environment)}] <${local.no_reply}>"
    }
  ]
}
