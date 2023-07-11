module "backend_uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.5.0"

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

  cloudwatch_log_group_name = data.aws_cloudwatch_log_groups.log_group.log_group_names

  service_environment_config = [
    {
      name  = "CDS"
      value = "true"
    },
    {
      name  = "GOVUK_APP_DOMAIN"
      value = "tariff-uk-backend-${local.environment_key}.apps.internal"
    },
    {
      name  = "NEW_RELIC_APP_NAME"
      value = "tariff-uk-backend-${var.environment}"
    },
    {
      name  = "SERVICE"
      value = "uk"
    },
    {
      name  = "TARIFF_FROM_EMAIL"
      value = "Tariff UK [${upper(var.environment)}] <${local.no_reply}>"
    },
    {
      name  = "backend_common_vars"
      value = local.backend_common_vars
    },
  ]

  service_secrets_config = [
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_connection_string.arn
    }
  ]
}
