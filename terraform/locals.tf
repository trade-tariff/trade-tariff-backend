locals {
  project         = "trade-tariff"
  no_reply        = "no-reply@${local.base_url}"
  base_url        = "${local.project}.service.gov.uk"
  environment_key = var.environment == "development" ? "development" : var.environment
}
