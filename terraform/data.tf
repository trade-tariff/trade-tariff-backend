data "aws_vpc" "vpc" {
  tags = { Name = "trade_tariff_${var.environment}_vpc" }
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

data "aws_lb_target_group" "this" {
  for_each = toset(["backend-uk-tg-${var.environment}", "backend-xi-tg-${var.environment}"])
  name     = each.value
}

data "aws_security_group" "this" {
  name = "trade-tariff-ecs-security-group-${var.environment}"
}

data "aws_secretsmanager_secret" "redis_connection_string" {
  name = "redis-backend-connection-string"
}

data "aws_secretsmanager_secret" "database_connection_string" {
  name = "backend-database-connection-string"
}

data "aws_ssm_parameter" "ecr_url" {
  name = "/${var.environment}/BACKEND_ECR_URL"
}

data "aws_secretsmanager_secret" "backend_secret_key_base" {
  name = "backend-secret-key-base"
}

data "aws_secretsmanager_secret" "newrelic_license_key" {
  name = "newrelic-license-key"
}

data "aws_kms_key" "secretsmanager_key" {
  key_id = "alias/secretsmanager-key"
}
