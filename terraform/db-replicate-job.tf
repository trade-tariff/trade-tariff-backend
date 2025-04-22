module "db-replicate-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.13.1"

  service_name = "db-replicate-job"
  service_count = 0
}
