locals {
  production_replication_object_prefixes = [
    "data/exchange_rates",
    "data/taric",
    "data/cds",
  ]
}

data "aws_iam_policy_document" "task" {
  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::trade-tariff-persistence-${local.account_id}",
      "arn:aws:s3:::trade-tariff-reporting-${local.account_id}",
      "arn:aws:s3:::trade-tariff-persistence-${local.account_id}/*",
      "arn:aws:s3:::trade-tariff-reporting-${local.account_id}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]
    # NOTE: READONLY access to production data files for replication
    resources = concat(
      ["arn:aws:s3:::trade-tariff-persistence-382373577178"],
      [
        for prefix in local.production_replication_object_prefixes :
        "arn:aws:s3:::trade-tariff-persistence-382373577178/${prefix}/*"
      ],
    )
  }

  statement {
    effect  = "Allow"
    actions = ["s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::trade-tariff-persistence-${local.account_id}/data/exchange_rates/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["arn:aws:cloudfront::${local.account_id}:distribution/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::trade-tariff-database-backups-${local.account_id}",
      "arn:aws:s3:::trade-tariff-database-backups-${local.account_id}/*",
    ]
  }
}

resource "aws_iam_policy" "task" {
  name   = "backend-task-role-policy"
  policy = data.aws_iam_policy_document.task.json
}

check "production_replication_object_prefixes" {
  assert {
    condition = toset(local.production_replication_object_prefixes) == toset([
      "data/exchange_rates",
      "data/taric",
      "data/cds",
    ])
    error_message = "Production replication read access must cover exchange rate, TARIC, and CDS objects."
  }
}
