locals {
  image = "${data.aws_ssm_parameter.ecr_url.value}:${var.docker_tag}"

  portMappings = [{
    protocol      = "tcp"
    containerPort = 8080
  }]

  logConfiguration = {
    logDriver = "awslogs"
    options = {
      awslogs-region        = var.region
      awslogs-stream-prefix = "ecs"
      awslogs-group         = "platform-logs-${var.environment}"
    }
  }

}

module "uk" {
  source = "./modules/service"

  service_name     = "backend-uk"
  service_count    = var.service_count
  cluster_name     = "trade-tariff-cluster-${var.environment}"
  security_groups  = [data.aws_security_group.this.id]
  subnet_ids       = data.aws_subnets.private.ids
  target_group_arn = data.aws_lb_target_group.this[0].arn

  private_dns_namespace = "tariff.internal"

  max_capacity = var.max_capacity
  min_capacity = var.min_capacity
  skip_destroy = true

  container_port = 8080
  cpu            = var.cpu
  memory         = var.memory

  execution_role_policy_arns = [
    aws_iam_policy.secrets
  ]

  task_role_policy_arns = [
    aws_iam_policy.s3.arn,
    aws_iam_policy.task_role_kms_keys.arn,
    aws_iam_policy.emails.arn
  ]

  container_definitions = [
    {
      name      = "backend-uk-init"
      image     = local.image
      essential = false
      command   = ["/bin/sh", "-c", "bundle exec rails db:migrate && bundle exec rails data:migrate"]

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "CDS"
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


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_uk_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "backend-uk"
      image     = local.image
      essential = true

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-uk-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "CDS"
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


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_uk_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_readonly_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "worker-uk"
      image     = local.image
      essential = true

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-uk-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "CDS"
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


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_uk_common_secrets,
        [
          {
            name      = "DATABASE_URL"
            valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
          }
        ]
      ])
    },
    {
      name      = "admin-uk"
      image     = local.image
      essential = true

      portMappings     = local.portMappings
      logConfiguration = local.logConfiguration

      dependsOn = [{
        containerName = "backend-uk-init"
        condition     = "SUCCESS"
      }]

      environment = flatten([
        local.backend_common_vars,
        [
          {
            name  = "CDS"
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


      secrets = flatten([
        local.backend_common_secrets,
        local.backend_uk_common_secrets,
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
