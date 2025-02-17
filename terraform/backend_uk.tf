module "backend_uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.12.0"

  region = var.region

  service_name  = "backend-uk"
  service_count = var.service_count

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  target_group_arn          = data.aws_lb_target_group.backend_uk.arn
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  min_capacity = var.min_capacity
  max_capacity = var.max_capacity

  docker_image = data.aws_ssm_parameter.ecr_url.value
  docker_tag   = var.docker_tag
  skip_destroy = true

  container_port        = 8080
  private_dns_namespace = "tariff.internal"

  cpu    = var.cpu
  memory = var.memory

  task_role_policy_arns = [
    aws_iam_policy.exec.arn,
    aws_iam_policy.s3.arn,
    aws_iam_policy.task_role_kms_keys.arn,
    aws_iam_policy.emails.arn
  ]

  execution_role_policy_arns = [
    aws_iam_policy.secrets.arn,
  ]

  service_environment_config = flatten([
    local.backend_common_vars,
    [
      {
        name  = "CDS"
        value = "true"
      },
      {
        name  = "ENABLE_ADMIN"
        value = "true"
      },
      {
        name  = "GOVUK_APP_DOMAIN"
        value = "tariff-uk-backend-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
      },
      {
        name  = "SERVICE"
        value = "uk"
      },
      {
        name  = "SLACK_USERNAME"
        value = "UK Backend API ${title(var.environment)}"
      },
      {
        name  = "TARIFF_FROM_EMAIL"
        value = "Tariff UK [${title(var.environment)}] <${local.no_reply}>"
      },
      {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    ]
  ])

  enable_ecs_exec = true

  service_secrets_config = flatten([
    local.backend_common_secrets,
    local.backend_uk_common_secrets,
    [
      {
        name      = "DATABASE_URL"
        valueFrom = local.read_write_db_arn
      }
    ]
  ])
}
