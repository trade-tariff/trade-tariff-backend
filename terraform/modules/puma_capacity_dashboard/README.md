# puma_capacity_dashboard

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_dashboard.puma_capacity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application"></a> [application](#input\_application) | Application name used in the dashboard name. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment dimension emitted by the reporter. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region containing the application logs and metrics. | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | Service dimensions emitted by the reporter (frontend, backend-uk, backend-xi). | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_puma_capacity_dashboard_name"></a> [puma\_capacity\_dashboard\_name](#output\_puma\_capacity\_dashboard\_name) | Puma capacity dashboard (metrics require manual enablement through the application configuration secret). |
<!-- END_TF_DOCS -->
