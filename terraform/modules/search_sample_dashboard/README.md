# search_sample_dashboard

CloudWatch Logs Insights dashboard for comparing Flagsmith-offered frontend search (`experiment = tenpct`) with unlabelled frontend search (control).

Sample is assignment, not use of guided search. Classic volume inside `tenpct` is expected. Control is not a clean 90% of users: it includes traffic from before the stamp, Flagsmith fallbacks, and unlabelled browsers. URL enrolments stay on Search Experiment.

Search totals and rates collapse to one row per `request_id` before aggregation. Distinct guided-search browser sessions are estimated for the selected window only and are not additive across hours. Query text is not displayed. Refresh is manual because each widget starts a new Logs Insights scan.

The empty-result predicates match Search Overview, Quality, and Experiment.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_dashboard.search_sample](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_name"></a> [dashboard\_name](#input\_dashboard\_name) | Name of the CloudWatch dashboard | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., development, staging, production) | `string` | n/a | yes |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | CloudWatch Log Group name where search instrumentation logs are sent | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dashboard_arn"></a> [dashboard\_arn](#output\_dashboard\_arn) | ARN of the CloudWatch dashboard |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Name of the CloudWatch dashboard |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | URL to the CloudWatch dashboard |
| <a name="output_queries"></a> [queries](#output\_queries) | Rendered queries and languages for read-only validation |
<!-- END_TF_DOCS -->
