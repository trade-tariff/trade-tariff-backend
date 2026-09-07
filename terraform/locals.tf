locals {
  has_autoscaler = var.environment == "development" ? false : true
  account_id     = data.aws_caller_identity.current.account_id
  worker_command = ["/bin/sh", "-c", "export DB_POOL=$${DB_POOL:-$${SIDEKIQ_CONCURRENCY:-10}} && bundle exec sidekiq -C ./config/sidekiq.yml"]
  job_command    = ["/bin/sh", "-c", "bin/null-service"]

  tls_secret = jsondecode(data.aws_secretsmanager_secret_version.ecs_tls_certificate.secret_string)

  api_service_env_vars = [
    {
      name  = "SSL_KEY_PEM"
      value = local.tls_secret.private_key
    },
    {
      name  = "SSL_CERT_PEM"
      value = local.tls_secret.certificate
    },
    {
      name  = "SSL_PORT"
      value = "8443"
    },
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
  backend_uk_service_env_vars = concat(local.backend_uk_secret_env_vars, local.api_service_env_vars)

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
  backend_xi_service_env_vars = concat(local.backend_xi_secret_env_vars, local.api_service_env_vars)

  backend_job_secret_value = try(data.aws_secretsmanager_secret_version.backend_job_configuration.secret_string, "{}")
  backend_job_secret_map   = jsondecode(local.backend_job_secret_value)
  backend_job_secret_env_vars = [
    for key, value in local.backend_job_secret_map : {
      name  = key
      value = value
    }
  ]
  ecr_repo = "382373577178.dkr.ecr.eu-west-2.amazonaws.com/tariff-backend-production"

  # Paths the image must still be able to write to under a read-only root filesystem.
  # WORKDIR is /app, so Rails.root-relative paths resolve there.
  #   /tmp      - Tempfile (CustomsTariffImporter::NotesExtractor) and general scratch
  #   /app/tmp  - bootsnap, loaded in config/boot.rb; without it the app fails to boot
  #   /app/log  - the New Relic agent's own log file (newrelic.yml sets no log_file)
  #
  # NOT /app/data: it ships eight tracked runtime files (guides.csv,
  # preference_codes.json, CN2026_SelfText_EN_DE_FR.csv, green_lanes/themes.html, ...)
  # and an ephemeral volume mounted there would mask all of them.
  writable_paths = ["/tmp", "/app/tmp", "/app/log"]

  # CdsImporter::ExcelWriter writes "CDS updates <date>.xlsx" into data/cds_updates with
  # no Rails.env guard, driven by CdsUpdateNotificationWorker — so only the Sidekiq
  # workers need it. Mounted at the subdirectory to leave the sibling files visible.
  worker_writable_paths = concat(local.writable_paths, ["/app/data/cds_updates"])

  # Matches the uid/gid pinned in the Dockerfile. The ecs-service module adds an init
  # container that chowns the writable mounts to this user, because Fargate mounts them
  # root-owned and the app runs as the non-root `tariff`.
  container_user = "1000:1000"
}
