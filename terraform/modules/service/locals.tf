data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.cluster_name
}

data "aws_service_discovery_dns_namespace" "this" {
  count = var.private_dns_namespace != null ? 1 : 0
  name  = var.private_dns_namespace
  type  = "DNS_PRIVATE"
}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  cluster_arn = data.aws_ecs_cluster.this.arn
  tags = merge({
    Terraform = true
  }, var.tags)
}
