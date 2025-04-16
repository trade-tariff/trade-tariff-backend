<!-- markdownlint-disable -->
# trade-tariff-frontend terraform

Terraform to deploy the service into AWS.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.94.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_backend_uk"></a> [backend\_uk](#module\_backend\_uk) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.13.1 |
| <a name="module_backend_xi"></a> [backend\_xi](#module\_backend\_xi) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.13.1 |
| <a name="module_worker_uk"></a> [worker\_uk](#module\_worker\_uk) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.13.1 |
| <a name="module_worker_xi"></a> [worker\_xi](#module\_worker\_xi) | git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service | aws/ecs-service-v1.13.1 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb_target_group.backend_uk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group) | data source |
| [aws_lb_target_group.backend_xi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group) | data source |
| [aws_secretsmanager_secret.backend_uk_api_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.backend_uk_worker_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.backend_xi_api_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret.backend_xi_worker_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.backend_uk_api_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.backend_uk_worker_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.backend_xi_api_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.backend_xi_worker_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU units to use. | `number` | n/a | yes |
| <a name="input_docker_tag"></a> [docker\_tag](#input\_docker\_tag) | Image tag to use. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment. | `string` | n/a | yes |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Largest number of tasks the service can scale-out to. | `number` | `5` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory to allocate in MB. Powers of 2 only. | `number` | n/a | yes |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Smallest number of tasks the service can scale-in to. | `number` | `1` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to use. | `string` | n/a | yes |
| <a name="input_service_count"></a> [service\_count](#input\_service\_count) | Number of services to use. | `number` | `2` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
