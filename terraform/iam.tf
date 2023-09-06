data "aws_iam_policy_document" "secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      data.aws_secretsmanager_secret.database_connection_string.arn,
      data.aws_secretsmanager_secret.newrelic_license_key.arn,
      data.aws_secretsmanager_secret.oauth_id.arn,
      data.aws_secretsmanager_secret.oauth_secret.arn,
      data.aws_secretsmanager_secret.redis_uk_connection_string.arn,
      data.aws_secretsmanager_secret.redis_xi_connection_string.arn,
      data.aws_secretsmanager_secret.secret_key_base.arn,
      data.aws_secretsmanager_secret.sentry_dsn.arn,
      data.aws_secretsmanager_secret.sync_host.arn,
      data.aws_secretsmanager_secret.sync_password.arn,
      data.aws_secretsmanager_secret.sync_username.arn,
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
      data.aws_kms_key.persistence_key.arn,
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
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
}

resource "aws_iam_policy" "exec" {
  name   = "backend-task-role-exec-policy"
  policy = data.aws_iam_policy_document.exec.json
}

data "aws_iam_policy_document" "spelling_corrector_bucket" {
  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      data.aws_s3_bucket.spelling_corrector.arn,
      data.aws_s3_bucket.persistence.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    # tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "${data.aws_s3_bucket.spelling_corrector.arn}/*",
      "${data.aws_s3_bucket.persistence.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3" {
  name   = "backend-task-role-s3-policy"
  policy = data.aws_iam_policy_document.spelling_corrector_bucket.json
}
