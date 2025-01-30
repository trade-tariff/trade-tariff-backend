locals {
  account_id     = data.aws_caller_identity.current.account_id
  no_reply       = "no-reply@${var.base_domain}"
  worker_command = ["/bin/sh", "-c", "bundle exec sidekiq -C ./config/sidekiq.yml"]
  init_command   = ["/bin/sh", "-c", "bundle exec rails db:migrate && bundle exec rails data:migrate"]
  signon_url     = var.environment == "production" ? "https://signon.publishing.service.gov.uk" : "http://signon.tariff.internal:8080"

  backend_common_vars = [
    {
      name  = "PORT"
      value = "8080"
    },
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
      value = data.aws_s3_bucket.persistence.bucket
    },
    {
      name  = "DB_POOL"
      value = "20"
    },
    {
      name  = "DEFAULT_API_VERSION"
      value = "1"
    },
    {
      name  = "FRONTEND_HOST"
      value = "https://${var.frontend_base_domain}/"
    },
    {
      name  = "LEGACY_SEARCH_ENHANCEMENTS_ENABLED"
      value = var.legacy_search_enhancements_enabled
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
      name  = "PLEK_SERVICE_SIGNON_URI"
      value = local.signon_url
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
      name  = "TARIFF_SUPPORT_EMAIL"
      value = "hmrc-trade-tariff-support-g@digital.hmrc.gov.uk"
    },
    {
      name  = "TARIFF_MANAGEMENT_EMAIL"
      value = var.management_email
    },
    {
      name  = "STEMMING_EXCLUSION_REFERENCE_ANALYZER"
      value = var.stemming_exclusion_reference_analyzer
    },
    {
      name  = "SYNONYM_REFERENCE_ANALYZER"
      value = var.synonym_reference_analyzer
    },
    {
      name  = "TARIFF_SYNC_EMAIL"
      value = "trade-tariff-support@enginegroup.com"
    },
    {
      name  = "TARIFF_IGNORE_PRESENCE_ERRORS"
      value = "1"
    },
    {
      name  = "TARIFF_QUERY_SEARCH_PARSER_URL"
      value = "http://search-query-parser.tariff.internal:8080/api/search"
    },
    {
      name  = "WEB_CONCURRENCY"
      value = "4"
    },
    {
      name  = "GREEN_LANES_UPDATE_EMAIL"
      value = var.green_lanes_update_email
    },
    {
      name  = "GREEN_LANES_NOTIFY_MEASURE_UPDATES"
      value = var.green_lanes_notify_measure_updates
    }
  ]

  backend_common_worker_vars = [
    {
      name  = "AWS_REPORTING_BUCKET_NAME"
      value = "trade-tariff-reporting-${local.account_id}"
    },
    {
      name  = "REPORTING_CDN_HOST"
      value = "https://reporting.${var.base_domain}/"
    },
    {
      name  = "SLACK_CHANNEL"
      value = "#tariffs-etl"
    },
    {
      name  = "TARIFF_SYNC_EMAIL"
      value = "hmrc-trade-tariff-support-g@digital.hmrc.gov.uk"
    },
    {
      name  = "XE_API_URL"
      value = "https://xecdapi.xe.com"
    },
    {
      name  = "NOEMAIL"
      value = var.noemail
    },
  ]

  backend_uk_common_secrets = [
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_uk_connection_string.arn
    },
  ]

  backend_xi_common_secrets = [
    {
      name      = "REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_xi_connection_string.arn
    },
  ]

  backend_uk_worker_secrets = [
    {
      name      = "DIFFERENCES_TO_EMAILS"
      valueFrom = data.aws_secretsmanager_secret.differences_to_emails.arn
    },
    {
      name      = "HMRC_API_HOST"
      valueFrom = data.aws_secretsmanager_secret.sync_uk_host.arn
    },
    {
      name      = "HMRC_CLIENT_ID"
      valueFrom = data.aws_secretsmanager_secret.sync_uk_username.arn
    },
    {
      name      = "HMRC_CLIENT_SECRET"
      valueFrom = data.aws_secretsmanager_secret.sync_uk_password.arn
    },
  ]

  backend_xi_worker_secrets = [
    {
      name      = "TARIFF_SYNC_HOST"
      valueFrom = data.aws_secretsmanager_secret.sync_xi_host.arn
    },
    {
      name      = "TARIFF_SYNC_USERNAME"
      valueFrom = data.aws_secretsmanager_secret.sync_xi_username.arn
    },
    {
      name      = "TARIFF_SYNC_PASSWORD"
      valueFrom = data.aws_secretsmanager_secret.sync_xi_password.arn
    },
  ]

  backend_common_secrets = [
    {
      name      = "ELASTICSEARCH_URL"
      valueFrom = data.aws_ssm_parameter.elasticsearch_url.arn
    },
    {
      name      = "FRONTEND_REDIS_URL"
      valueFrom = data.aws_secretsmanager_secret.redis_frontend_connection_string.arn
    },
    {
      name      = "GREEN_LANES_API_TOKENS"
      valueFrom = data.aws_secretsmanager_secret.green_lanes_api_tokens.arn
    },
    {
      name      = "GREEN_LANES_API_KEYS"
      valueFrom = data.aws_secretsmanager_secret.green_lanes_api_keys.arn
    },
    {
      name      = "NEW_RELIC_LICENSE_KEY"
      valueFrom = data.aws_secretsmanager_secret.new_relic_license_key.arn
    },
    {
      name      = "SENTRY_DSN"
      valueFrom = data.aws_secretsmanager_secret.sentry_dsn.arn
    },
    {
      name      = "SECRET_KEY_BASE"
      valueFrom = data.aws_secretsmanager_secret.secret_key_base.arn
    },
    {
      name      = "SLACK_WEB_HOOK_URL"
      valueFrom = data.aws_secretsmanager_secret.slack_web_hook_url.arn
    },
    {
      name      = "TRADE_TARIFF_OAUTH_ID"
      valueFrom = data.aws_secretsmanager_secret.oauth_id.arn
    },
    {
      name      = "TRADE_TARIFF_OAUTH_SECRET"
      valueFrom = data.aws_secretsmanager_secret.oauth_secret.arn
    },
    {
      name      = "XE_API_USERNAME"
      valueFrom = data.aws_secretsmanager_secret.xe_api_username.arn
    },
    {
      name      = "XE_API_PASSWORD"
      valueFrom = data.aws_secretsmanager_secret.xe_api_password.arn
    },
  ]
}
