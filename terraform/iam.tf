locals {
  production_replication_object_prefixes = [
    "data/exchange_rates",
    "data/taric",
    "data/cds",
  ]

  # The identity user pool that holds the email distribution lists (dl-*
  # Cognito groups), from the services that send those emails. The secrets
  # are sensitive, and Terraform does not accept a sensitive value in
  # for_each. A pool ID is an identifier (it is in the policy ARN), not a
  # credential. sensitive() first, so nonsensitive() never gets a plain value.
  distribution_list_user_pool_ids = nonsensitive(sensitive(toset(compact([
    for secret_map in [local.worker_uk_secret_map, local.worker_xi_secret_map, local.backend_job_secret_map] :
    trimspace(try(secret_map["COGNITO_USER_POOL_ID"], ""))
  ]))))
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
      "logs:GetQueryResults",
      "logs:StopQuery"
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
      "s3:GetObjectTagging",
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

  # Read the members of the email distribution lists. Added only when a
  # sending service has COGNITO_USER_POOL_ID; without it the backend uses the
  # old recipient env vars.
  dynamic "statement" {
    for_each = length(local.distribution_list_user_pool_ids) > 0 ? [1] : []

    content {
      effect  = "Allow"
      actions = ["cognito-idp:ListUsersInGroup"]
      resources = [
        for pool_id in local.distribution_list_user_pool_ids :
        "arn:aws:cognito-idp:${var.region}:${local.account_id}:userpool/${pool_id}"
      ]
    }
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
