data "aws_iam_policy_document" "secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = compact([
      data.aws_secretsmanager_secret.aurora_rw_connection_string.arn,
      data.aws_secretsmanager_secret.cupid_team_to_emails.arn,
      data.aws_secretsmanager_secret.differences_to_emails.arn,
      data.aws_secretsmanager_secret.green_lanes_api_keys.arn,
      data.aws_secretsmanager_secret.green_lanes_api_tokens.arn,
      data.aws_secretsmanager_secret.new_relic_license_key.arn,
      data.aws_secretsmanager_secret.oauth_id.arn,
      data.aws_secretsmanager_secret.oauth_secret.arn,
      data.aws_secretsmanager_secret.redis_frontend_connection_string.arn,
      data.aws_secretsmanager_secret.redis_uk_connection_string.arn,
      data.aws_secretsmanager_secret.redis_xi_connection_string.arn,
      data.aws_secretsmanager_secret.secret_key_base.arn,
      data.aws_secretsmanager_secret.slack_web_hook_url.arn,
      data.aws_secretsmanager_secret.sync_uk_host.arn,
      data.aws_secretsmanager_secret.sync_uk_password.arn,
      data.aws_secretsmanager_secret.sync_uk_username.arn,
      data.aws_secretsmanager_secret.sync_xi_host.arn,
      data.aws_secretsmanager_secret.sync_xi_password.arn,
      data.aws_secretsmanager_secret.sync_xi_username.arn,
      data.aws_secretsmanager_secret.xe_api_password.arn,
      data.aws_secretsmanager_secret.xe_api_username.arn,
    ])
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKeyPairWithoutPlainText",
      "kms:GenerateDataKeyWithoutPlaintext"
    ]
    resources = [
      data.aws_kms_key.secretsmanager_key.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      data.aws_ssm_parameter.elasticsearch_url.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKeyPairWithoutPlainText",
      "kms:GenerateDataKeyWithoutPlaintext"
    ]
    resources = [
      data.aws_kms_key.secretsmanager_key.arn,
      data.aws_kms_key.opensearch_key.arn
    ]
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "backend-execution-role-secrets-policy"
  policy = data.aws_iam_policy_document.secrets.json
}

data "aws_iam_policy_document" "task_role_kms_keys" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKeyPairWithoutPlainText",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
    resources = [
      data.aws_kms_key.opensearch_key.arn,
      data.aws_kms_key.s3_key.arn,
    ]
  }
}

resource "aws_iam_policy" "task_role_kms_keys" {
  name   = "backend-task-role-kms-keys-policy"
  policy = data.aws_iam_policy_document.task_role_kms_keys.json
}

data "aws_iam_policy_document" "exec" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "exec" {
  name   = "backend-task-role-exec-policy"
  policy = data.aws_iam_policy_document.exec.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      data.aws_s3_bucket.persistence.arn,
      data.aws_s3_bucket.reporting.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${data.aws_s3_bucket.persistence.arn}/*",
      "${data.aws_s3_bucket.reporting.arn}/*"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:DeleteObject"]
    resources = [
      "${data.aws_s3_bucket.persistence.arn}/data/exchange_rates/*",
    ]
  }
}

resource "aws_iam_policy" "s3" {
  name   = "backend-task-role-s3-policy"
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "emails" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "emails" {
  name   = "frontend-execution-role-emails-policy"
  policy = data.aws_iam_policy_document.emails.json
}
