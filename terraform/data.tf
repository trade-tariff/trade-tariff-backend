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
  name = "trade-tariff-be-tg-${var.environment}"
}

data "aws_security_group" "this" {
  name = "trade-tariff-ecs-security-group-${var.environment}"
}

data "aws_secretsmanager_secret" "redis_connection_string" {
  name = "redis-connection-string"
}

data "aws_ssm_parameter" "ecr_url" {
  name = "/${var.environment}/BACKEND_ECR_URL"
}

data "aws_cloudwatch_log_groups" "log_group" {}
