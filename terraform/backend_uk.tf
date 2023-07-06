module "backend_uk" {
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

  service_environment_config = [
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
      value = "https://${local.environment_key}.${local.base_url}/"
      # TODO: scope this due to www
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
      name  = "NEW_RELIC_APP_NAME"
      value = "tariff-uk-backend-${var.environment}"
    },
    {
      name  = "NEW_RELIC_DISTRIBUTED_TRACING"
      value = "true"
    },
    {
      name  = "PAAS_S3_SERVICE_NAME"
      value = "tariff-pdf-${local.environment_key}"
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
      name  = "SECRET_KEY_BASE"
      value = var.tariff_backend_secret_key_base
    },
    {
      name  = "SENTRY_DSN"
      value = var.tariff_backend_sentry_dsn
    },
    {
      name  = "SENTRY_PROJECT"
      value = var.sentry_project
    },
    {
      name  = "SPELLING_CORRECTOR_BUCKET_NAME"
      value = "trade-tariff-search-configuration-${var.environment}"
    },
    {
      name  = "STEMMING_EXCLUSION_REFERENCE_ANALYZER"
      value = "analyzers/F102794475"
    },
    {
      name  = "SYNONYM_REFERENCE_ANALYZER"
      value = "analyzers/F135140295"
    },
    {
      name  = "TARIFF_IGNORE_PRESENCE_ERRORS"
      value = "1"
    },
    {
      name  = "TARIFF_MEASURES_LOGGER"
      value = "1"
    },
    {
      name  = "TARIFF_QUERY_SEARCH_PARSER_URL"
      value = "http://tariff-search-query-parser-${local.environment_key}.apps.internal:8080/api/search/"
    },
    {
      name  = "TARIFF_SYNC_EMAIL"
      value = var.tariff_backend_sync_email
    },
    {
      name  = "TARIFF_SYNC_HOST"
      value = var.tariff_backend_sync_host
    },
    {
      name  = "TARIFF_SYNC_PASSWORD"
      value = var.tariff_backend_sync_password
    },
    {
      name  = "TARIFF_SYNC_USERNAME"
      value = var.tariff_backend_sync_username
    },
    {
      name  = "TRADE_TARIFF_OAUTH_ID"
      value = var.tariff_backend_oauth_id
    },
    {
      name  = "TRADE_TARIFF_OAUTH_SECRET"
      value = var.tariff_backend_oauth_secret
    },
    {
      name  = "WEB_CONCURRENCY"
      value = "4"
    },
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_connection_string.arn
    }
  ]
}
