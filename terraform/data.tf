data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  tags = { Name = "trade-tariff-${var.environment}-vpc" }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Name = "*private*"
  }
}

data "aws_security_group" "this" {
  name = "trade-tariff-ecs-security-group-${var.environment}"
}

data "aws_ssm_parameter" "ecr_url" {
  name = "/${var.environment}/BACKEND_ECR_URL"
}

data "aws_ssm_parameter" "elasticsearch_url" {
  name = "/${var.environment}/ELASTICSEARCH_URL"
}

data "aws_kms_key" "secretsmanager_key" {
  key_id = "alias/secretsmanager-key"
}

data "aws_kms_key" "opensearch_key" {
  key_id = "alias/opensearch-key"
}

data "aws_kms_key" "s3_key" {
  key_id = "alias/s3-key"
}

data "aws_secretsmanager_secret" "redis_uk_connection_string" {
  name = "redis-backend-uk-connection-string"
}

data "aws_secretsmanager_secret" "redis_xi_connection_string" {
  name = "redis-backend-xi-connection-string"
}

data "aws_secretsmanager_secret" "redis_frontend_connection_string" {
  name = "redis-frontend-connection-string"
}

data "aws_secretsmanager_secret" "aurora_rw_connection_string" {
  name = "aurora-postgres-rw-connection-string"
}

data "aws_secretsmanager_secret" "secret_key_base" {
  name = "backend-secret-key-base"
}

data "aws_secretsmanager_secret" "slack_web_hook_url" {
  name = "slack-web-hook-url"
}

data "aws_secretsmanager_secret" "sentry_dsn" {
  name = "backend-sentry-dsn"
}

data "aws_secretsmanager_secret" "differences_to_emails" {
  name = "backend-differences-to-emails"
}

data "aws_secretsmanager_secret" "sync_uk_host" {
  name = "backend-uk-sync-host"
}

data "aws_secretsmanager_secret" "sync_uk_password" {
  name = "backend-uk-sync-password"
}

data "aws_secretsmanager_secret" "sync_uk_username" {
  name = "backend-uk-sync-username"
}

data "aws_secretsmanager_secret" "sync_xi_host" {
  name = "backend-xi-sync-host"
}

data "aws_secretsmanager_secret" "sync_xi_password" {
  name = "backend-xi-sync-password"
}

data "aws_secretsmanager_secret" "sync_xi_username" {
  name = "backend-xi-sync-username"
}

data "aws_secretsmanager_secret" "oauth_id" {
  name = "backend-oauth-id"
}

data "aws_secretsmanager_secret" "oauth_secret" {
  name = "backend-oauth-secret"
}

data "aws_secretsmanager_secret" "xe_api_username" {
  name = "backend-xe-api-username"
}

data "aws_secretsmanager_secret" "xe_api_password" {
  name = "backend-xe-api-password"
}

data "aws_secretsmanager_secret" "green_lanes_api_tokens" {
  name = "backend-green-lanes-api-tokens"
}

data "aws_secretsmanager_secret" "green_lanes_api_keys" {
  name = "backend-green-lanes-api-keys"
}

data "aws_secretsmanager_secret" "new_relic_license_key" {
  name = "backend-new-relic-license-key"
}

data "aws_s3_bucket" "persistence" {
  bucket = "trade-tariff-persistence-${local.account_id}"
}

data "aws_s3_bucket" "reporting" {
  bucket = "trade-tariff-reporting-${local.account_id}"
}

data "aws_lb_target_group" "backend_uk" {
  name = "backend-uk"
}

data "aws_lb_target_group" "backend_xi" {
  name = "backend-xi"
}
