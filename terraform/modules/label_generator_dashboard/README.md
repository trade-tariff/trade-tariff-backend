# Label Generator CloudWatch Dashboard

Terraform module to create a CloudWatch dashboard and alarms for monitoring the label generation ETL process.

## Features

- **Dashboard** with Log Insights queries for:
  - Generation run overview
  - Success rate tracking
  - Throughput (labels/hour)
  - API latency percentiles (p50, p95)
  - Page processing times
  - Error breakdowns by type
  - Data quality issues (mismatches, not found)

- **Metric Filters** to extract metrics from structured JSON logs:
  - `LabelGeneratorAPIFailures`
  - `LabelGeneratorPageFailures`
  - `LabelGeneratorSaveFailures`
  - `LabelGeneratorLabelsCreated`
  - `LabelGeneratorAPILatency`

- **Alarms** (optional, requires SNS topic):
  - API failure threshold
  - Page failure threshold
  - High API latency (p95 > 30s)
  - No labels created (stalled generation)

## Usage

```hcl
module "label_generator_dashboard" {
  source = "./modules/label_generator_dashboard"

  environment    = "production"
  log_group_name = "/aws/ecs/trade-tariff-backend-production"
  region         = "eu-west-2"

  # Optional: Enable alarms
  alarm_sns_topic_arn = aws_sns_topic.alerts.arn
  api_error_threshold = 5
  page_error_threshold = 3
}

output "dashboard_url" {
  value = module.label_generator_dashboard.dashboard_url
}
```

## Without Alarms

```hcl
module "label_generator_dashboard" {
  source = "./modules/label_generator_dashboard"

  environment    = "development"
  log_group_name = "/aws/ecs/trade-tariff-backend-development"
  region         = "eu-west-2"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| log_group_name | CloudWatch Log Group name | `string` | n/a | yes |
| region | AWS region | `string` | `"eu-west-2"` | no |
| dashboard_name | Custom dashboard name | `string` | `null` | no |
| alarm_sns_topic_arn | SNS topic for alarms | `string` | `null` | no |
| api_error_threshold | API failures before alarm | `number` | `5` | no |
| page_error_threshold | Page failures before alarm | `number` | `3` | no |

## Outputs

| Name | Description |
|------|-------------|
| dashboard_arn | ARN of the CloudWatch dashboard |
| dashboard_name | Name of the CloudWatch dashboard |
| dashboard_url | URL to access the dashboard |
| metric_namespace | CloudWatch metric namespace |
| alarm_arns | Map of alarm ARNs (if created) |

## Log Format Expected

The module expects structured JSON logs with these fields:

```json
{
  "service": "label_generator",
  "event": "api_call_completed",
  "timestamp": "2026-01-20T15:30:00Z",
  "batch_size": 10,
  "results_count": 10,
  "model": "o3-pro",
  "duration_ms": 2341.5
}
```

See `app/lib/label_generator/logger.rb` for the full list of events and fields.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_dashboard.label_generator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_log_metric_filter.api_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.api_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.label_save_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.labels_created](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_metric_filter.page_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.api_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.high_api_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.no_labels_created](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.page_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topic_arn"></a> [alarm\_sns\_topic\_arn](#input\_alarm\_sns\_topic\_arn) | SNS topic ARN for alarm notifications (optional) | `string` | `null` | no |
| <a name="input_api_error_threshold"></a> [api\_error\_threshold](#input\_api\_error\_threshold) | Number of API failures before alarming | `number` | `5` | no |
| <a name="input_dashboard_name"></a> [dashboard\_name](#input\_dashboard\_name) | Name of the CloudWatch dashboard | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., development, staging, production) | `string` | n/a | yes |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | CloudWatch Log Group name where label generator logs are sent | `string` | n/a | yes |
| <a name="input_page_error_threshold"></a> [page\_error\_threshold](#input\_page\_error\_threshold) | Number of page failures before alarming | `number` | `3` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alarm_arns"></a> [alarm\_arns](#output\_alarm\_arns) | ARNs of the CloudWatch alarms (if created) |
| <a name="output_dashboard_arn"></a> [dashboard\_arn](#output\_dashboard\_arn) | ARN of the CloudWatch dashboard |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Name of the CloudWatch dashboard |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | URL to the CloudWatch dashboard |
| <a name="output_metric_namespace"></a> [metric\_namespace](#output\_metric\_namespace) | CloudWatch metric namespace for label generator metrics |
<!-- END_TF_DOCS -->
