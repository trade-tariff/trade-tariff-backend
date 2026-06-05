# tariff_note_pipeline_dashboard

CloudWatch Logs Insights dashboard for the tariff note pipeline.

The dashboard follows the RED model:

- **Rate**: import runs, document outcomes, status changes and note edits.
- **Errors**: failed import runs, fetches, parses and document imports.
- **Duration**: import run, fetch, parse and document import latency percentiles.
- **Review backlog**: pending tariff note updates recorded on import completion and status changes.

It reads structured JSON logs emitted by `CustomsTariffImporter::Logger` with `service = "customs_tariff_importer"`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.12.0 |
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
| [aws_cloudwatch_dashboard.tariff_note_pipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_name"></a> [dashboard\_name](#input\_dashboard\_name) | Name of the CloudWatch dashboard | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., development, staging, production) | `string` | n/a | yes |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | CloudWatch Log Group name where tariff note pipeline logs are sent | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dashboard_arn"></a> [dashboard\_arn](#output\_dashboard\_arn) | ARN of the CloudWatch dashboard |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Name of the CloudWatch dashboard |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | URL to the CloudWatch dashboard |
<!-- END_TF_DOCS -->
