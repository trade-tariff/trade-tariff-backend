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

data "aws_lb_target_group" "backend_uk" {
  name = "backend-uk"
}

data "aws_lb_target_group" "backend_xi" {
  name = "backend-xi"
}

data "aws_secretsmanager_secret" "backend_uk_worker_configuration" {
  name = "backend-uk-worker-configuration"
}

data "aws_secretsmanager_secret_version" "backend_uk_worker_configuration" {
  secret_id = data.aws_secretsmanager_secret.backend_uk_worker_configuration.id
}

data "aws_secretsmanager_secret" "backend_uk_api_configuration" {
  name = "backend-uk-api-configuration"
}

data "aws_secretsmanager_secret_version" "backend_uk_api_configuration" {
  secret_id = data.aws_secretsmanager_secret.backend_uk_api_configuration.id
}

data "aws_secretsmanager_secret" "backend_xi_worker_configuration" {
  name = "backend-xi-worker-configuration"
}

data "aws_secretsmanager_secret_version" "backend_xi_worker_configuration" {
  secret_id = data.aws_secretsmanager_secret.backend_xi_worker_configuration.id
}

data "aws_secretsmanager_secret" "backend_xi_api_configuration" {
  name = "backend-xi-api-configuration"
}

data "aws_secretsmanager_secret_version" "backend_xi_api_configuration" {
  secret_id = data.aws_secretsmanager_secret.backend_xi_api_configuration.id
}
