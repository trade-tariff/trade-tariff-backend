module "backup_uk" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.12.0"

  service_name = "backup-uk"
  region       = var.region

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  service_count = 1
  min_capacity  = 1
  max_capacity  = var.max_capacity

  docker_image = data.aws_ssm_parameter.ecr_url.value
  docker_tag   = var.docker_tag
  skip_destroy = true

  container_port        = 8080
  private_dns_namespace = "tariff.internal"

  cpu    = 2048
  memory = 8192

  task_role_policy_arns = [
    aws_iam_policy.exec.arn,
    aws_iam_policy.s3.arn,
    aws_iam_policy.task_role_kms_keys.arn,
    aws_iam_policy.emails.arn
  ]

  execution_role_policy_arns = [
    aws_iam_policy.secrets.arn
  ]

  enable_ecs_exec = true

  container_entrypoint = [""]
  container_command    = local.backup_command

  init_container            = true
  init_container_entrypoint = [""]
  init_container_command    = local.init_command

  service_environment_config = flatten([
    local.backend_common_vars,
    local.backend_common_worker_vars,
    [
      {
        name  = "CDS"
        value = "true"
      },
      {
        name  = "GOVUK_APP_DOMAIN"
        value = "tariff-uk-worker-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
      },
      {
        name  = "SERVICE"
        value = "uk"
      },
      {
        name  = "SCHEMA_EXTENSION"
        value = "backup"
      },
      {
        name  = "SLACK_USERNAME"
        value = "UK Backend Worker ${title(var.environment)}"
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

  service_secrets_config = flatten([
    local.backend_common_secrets,
    local.backend_uk_common_secrets,
    local.backend_uk_worker_secrets,
    [
      {
        name      = "DATABASE_URL"
        valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
      }
    ]
  ])
}
