module "xi" {
  source = "./modules/service"

  service_name     = "backend-xi"
  service_count    = var.service_count
  cluster_name     = "trade-tariff-cluster-${var.environment}"
  security_groups  = [data.aws_security_group.this.id]
  subnet_ids       = data.aws_subnets.private.ids
  target_group_arn = data.aws_lb_target_group.this["backend-xi"].arn

  private_dns_namespace = "tariff.internal"

  max_capacity = var.max_capacity
  min_capacity = var.min_capacity
  skip_destroy = true

  container_port = 8080
  cpu            = var.cpu
  memory         = var.memory

  execution_role_policy_arns = [
    aws_iam_policy.secrets.arn
  ]

  task_role_policy_arns = [
    aws_iam_policy.s3.arn,
    aws_iam_policy.task_role_kms_keys.arn,
    aws_iam_policy.emails.arn
  ]

  container_definitions = [
    {
      name      = "backend-xi-init"
      image     = local.image
      essential = "false"
      command   = ["/bin/sh", "-c", "bundle exec rails db:migrate && bundle exec rails data:migrate"]

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "GOVUK_APP_DOMAIN"
            value = "tariff-xi-backend-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
          },
          {
            name  = "SERVICE"
            value = "xi"
          },
          {
            name  = "SLACK_USERNAME"
            value = "XI Backend API ${title(var.environment)}"
          },
          {
            name  = "TARIFF_FROM_EMAIL"
            value = "Tariff XI [${title(var.environment)}] <${local.no_reply}>"
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          }
        ]
      ])


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_xi_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "backend-xi"
      image     = local.image
      essential = "true"

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-xi-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "GOVUK_APP_DOMAIN"
            value = "tariff-xi-backend-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
          },
          {
            name  = "SERVICE"
            value = "xi"
          },
          {
            name  = "SLACK_USERNAME"
            value = "XI Backend API ${title(var.environment)}"
          },
          {
            name  = "TARIFF_FROM_EMAIL"
            value = "Tariff XI [${title(var.environment)}] <${local.no_reply}>"
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          }
        ]
      ])


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_xi_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_readonly_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "worker-xi"
      image     = local.image
      essential = "true"

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-xi-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "GOVUK_APP_DOMAIN"
            value = "tariff-xi-backend-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
          },
          {
            name  = "SERVICE"
            value = "xi"
          },
          {
            name  = "SLACK_USERNAME"
            value = "XI Backend API ${title(var.environment)}"
          },
          {
            name  = "TARIFF_FROM_EMAIL"
            value = "Tariff XI [${title(var.environment)}] <${local.no_reply}>"
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          }
        ]
      ])


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_xi_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "admin-xi"
      image     = local.image
      essential = "true"

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-xi-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "GOVUK_APP_DOMAIN"
            value = "tariff-xi-backend-${var.environment}.apps.internal" # This is necessary for a GOVUK gem we're not using
          },
          {
            name  = "SERVICE"
            value = "xi"
          },
          {
            name  = "SLACK_USERNAME"
            value = "XI Backend API ${title(var.environment)}"
          },
          {
            name  = "TARIFF_FROM_EMAIL"
            value = "Tariff XI [${title(var.environment)}] <${local.no_reply}>"
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          }
        ]
      ])


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_xi_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
          }
        ]
      ])
    }
  ]
}
