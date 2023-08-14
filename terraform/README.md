# trade-tariff-frontend terraform

Terraform to deploy the service into AWS.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.67.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_backend_uk"></a> [backend\_uk](#module\_backend\_uk) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.8.0 |
| <a name="module_backend_xi"></a> [backend\_xi](#module\_backend\_xi) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.8.0 |
| <a name="module_worker_uk"></a> [worker\_uk](#module\_worker\_uk) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | d178ba0 |
| <a name="module_worker_xi"></a> [worker\_xi](#module\_worker\_xi) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | d178ba0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_document.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_key.secretsmanager_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group) | data source |
| [aws_secretsmanager_secret.database_connection_string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.newrelic_license_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.oauth_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.oauth_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.redis_connection_string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.secret_key_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.sentry_dsn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.sync_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_ssm_parameter.ecr_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.elasticsearch_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alcohol_coercian_starts_from"></a> [alcohol\_coercian\_starts\_from](#input\_alcohol\_coercian\_starts\_from) | When alcohol measurement unit coercian starts from for excise measurement units | `string` | `"2023-01-01"` | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | URL of the service. | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU units to use. | `number` | n/a | yes |
| <a name="input_docker_tag"></a> [docker\_tag](#input\_docker\_tag) | Image tag to use. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment. | `string` | n/a | yes |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Largest number of tasks the service can scale-out to. | `number` | `5` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory to allocate in MB. Powers of 2 only. | `number` | n/a | yes |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Smallest number of tasks the service can scale-in to. | `number` | `1` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to use. | `string` | n/a | yes |
| <a name="input_service_count"></a> [service\_count](#input\_service\_count) | Number of services to use. | `number` | `2` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the service | `string` | `"backend"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
