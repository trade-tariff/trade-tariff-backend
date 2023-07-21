locals {
  no_reply = "no-reply@trade-tariff.service.gov.uk"
}

locals {
  backend_common_vars = [
    {
      name  = "ALCOHOL_COERCIAN_STARTS_FROM"
      value = var.alcohol_coercian_starts_from
    },
    {
      name  = "ALLOW_MISSING_MIGRATION_FILES"
      value = "true"
    },
    {
      name  = "AWS_BUCKET_NAME"
      value = "trade-tariff-persistence-${var.environment}"
    },
    {
      name  = "BETA_SEARCH_MAX_HITS"
      value = "1000"
    },
    {
      name  = "DB_POOL"
      value = "20"
    },
    {
      name  = "FRONTEND_HOST"
      value = "https://${var.base_domain}/"
    },
    {
      name  = "MALLOC_ARENA_MAX"
      value = "2"
    },
    {
      name  = "MAX_THREADS"
      value = "6"
    },
    {
      name  = "NEW_RELIC_AGENT_ENABLED"
      value = "false"
    },
    {
      name  = "NEW_RELIC_DISTRIBUTED_TRACING"
      value = "false"
    },
    {
      name  = "PLEK_SERVICE_SIGNON_URI"
      value = "https://signon-dev.london.cloudapps.digital"
    },
    {
      name  = "RACK_TIMEOUT_SERVICE"
      value = "50"
    },
    {
      name  = "RACK_TIMEOUT_SERVICE_TIMEOUT"
      value = "50"
    },
    {
      name  = "RACK_TIMEOUT_WAIT_TIMEOUT"
      value = "100"
    },
    {
      name  = "RUBYOPT",
      value = "--enable-yjit"
    },
    {
      name  = "SENTRY_ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "SENTRY_PROJECT"
      value = "tariff-backend"
    },
    {
      name  = "SPELLING_CORRECTOR_BUCKET_NAME"
      value = "trade-tariff-search-configuration-${var.environment}"
    },
    {
      name  = "STEMMING_EXCLUSION_REFERENCE_ANALYZER"
      value = "analyzers/F159568045"
    },
    {
      name  = "SYNONYM_REFERENCE_ANALYZER"
      value = "analyzers/F202143497"
    },
    {
      name  = "TARIFF_IGNORE_PRESENCE_ERRORS"
      value = "1"
    },
    {
      name  = "TARIFF_QUERY_SEARCH_PARSER_URL"
      value = "https://search-query-parser.tariff.internal:8080/api/search"
    },
    {
      name  = "WEB_CONCURRENCY"
      value = "4"
    }
  ]

  # backend_common_worker_vars = [
  #   {
  #     name  = "TARIFF_SYNC_EMAIL"
  #     value = "trade-tariff-support@enginegroup.com"
  #   },
  #   {
  #     name  = "TARIFF_SYNC_HOST"
  #     value = "https://webservices.hmrc.gov.uk"
  #   },
  #   {
  #     name  = "SLACK_CHANNEL"
  #     value = "#tariffs-etl"
  #   },
  # ]

  backend_uk_common_secrets = [
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_connection_string.arn # TODO: Replace with UK-specific redis connection string
    },
  ]

  backend_xi_common_secrets = [
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_connection_string.arn # TODO: Replace with XI-specific redis connection string
    },
  ]

  backend_common_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = data.aws_secretsmanager_secret.database_connection_string.arn
    }
  ]
}
