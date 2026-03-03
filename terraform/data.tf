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
  name = "backend-uk-tls"
}

data "aws_lb_target_group" "backend_xi" {
  name = "backend-xi-tls"
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

data "aws_secretsmanager_secret" "backend_job_configuration" {
  name = "backend-job-configuration"
}

data "aws_secretsmanager_secret_version" "backend_job_configuration" {
  secret_id = data.aws_secretsmanager_secret.backend_job_configuration.id
}

data "aws_secretsmanager_secret" "ecs_tls_certificate" {
  name = "ecs-tls-certificate"
}

data "aws_secretsmanager_secret_version" "ecs_tls_certificate" {
  secret_id = data.aws_secretsmanager_secret.ecs_tls_certificate.id
}

data "aws_sns_topic" "slack_topic" {
  name = "slack-topic"
}

data "aws_ecs_cluster" "this" {
  cluster_name = "trade-tariff-cluster-${var.environment}"
}

data "aws_ecs_task_definition" "backend_job" {
  task_definition = "backend-job-${local.account_id}"
  depends_on      = [module.backend-job]
}
