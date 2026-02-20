locals {
  has_autoscaler = var.environment == "development" ? false : true
  account_id     = data.aws_caller_identity.current.account_id
  worker_command = ["/bin/sh", "-c", "bundle exec sidekiq -C ./config/sidekiq.yml"]
  init_command   = ["/bin/sh", "-c", "bundle exec rails db:migrate && bundle exec rails data:migrate"]
  job_command    = ["/bin/sh", "-c", "bin/null-service"]

  ecs_tls_env_vars = [
    {
      name      = "SSL_KEY_PEM"
      valueFrom = "${data.aws_secretsmanager_secret.ecs_tls_certificate.arn}:private_key::"
    },
    {
      name      = "SSL_CERT_PEM"
      valueFrom = "${data.aws_secretsmanager_secret.ecs_tls_certificate.arn}:certificate::"
    },
    {
      name  = "SSL_PORT"
      value = "8443"
    }
  ]

  worker_uk_secret_value = try(data.aws_secretsmanager_secret_version.backend_uk_worker_configuration.secret_string, "{}")
  worker_uk_secret_map   = jsondecode(local.worker_uk_secret_value)
  worker_uk_secret_env_vars = [
    for key, value in local.worker_uk_secret_map : {
      name  = key
      value = value
    }
  ]

  backend_uk_secret_value = try(data.aws_secretsmanager_secret_version.backend_uk_api_configuration.secret_string, "{}")
  backend_uk_secret_map   = jsondecode(local.backend_uk_secret_value)
  backend_uk_secret_env_vars = [
    for key, value in local.backend_uk_secret_map : {
      name  = key
      value = value
    }
  ]
  backend_uk_service_env_vars = concat(local.backend_uk_secret_env_vars, local.ecs_tls_env_vars)

  worker_xi_secret_value = try(data.aws_secretsmanager_secret_version.backend_xi_worker_configuration.secret_string, "{}")
  worker_xi_secret_map   = jsondecode(local.worker_xi_secret_value)
  worker_xi_secret_env_vars = [
    for key, value in local.worker_xi_secret_map : {
      name  = key
      value = value
    }
  ]

  backend_xi_secret_value = try(data.aws_secretsmanager_secret_version.backend_xi_api_configuration.secret_string, "{}")
  backend_xi_secret_map   = jsondecode(local.backend_xi_secret_value)
  backend_xi_secret_env_vars = [
    for key, value in local.backend_xi_secret_map : {
      name  = key
      value = value
    }
  ]
  backend_xi_service_env_vars = concat(local.backend_xi_secret_env_vars, local.ecs_tls_env_vars)

  backend_job_secret_value = try(data.aws_secretsmanager_secret_version.backend_job_configuration.secret_string, "{}")
  backend_job_secret_map   = jsondecode(local.backend_job_secret_value)
  backend_job_secret_env_vars = [
    for key, value in local.backend_job_secret_map : {
      name  = key
      value = value
    }
  ]
  ecr_repo = "382373577178.dkr.ecr.eu-west-2.amazonaws.com/tariff-backend-production"
}
