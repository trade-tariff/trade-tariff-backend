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
      data.aws_secretsmanager_secret.oauth_id.arn,
      data.aws_secretsmanager_secret.oauth_secret.arn,
      data.aws_secretsmanager_secret.redis_connection_string.arn,
      data.aws_secretsmanager_secret.secret_key_base.arn,
      data.aws_secretsmanager_secret.sentry_dsn.arn,
      data.aws_secretsmanager_secret.sync_password.arn,
      data.aws_secretsmanager_secret.newrelic_license_key.arn
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
      data.aws_kms_key.secretsmanager_key.arn
    ]
  }
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

resource "aws_iam_policy" "secrets" {
  name   = "backend-execution-role-secrets-policy"
  policy = data.aws_iam_policy_document.secrets.json
}

resource "aws_iam_policy" "exec" {
  name   = "backend-task-role-exec-policy"
  policy = data.aws_iam_policy_document.exec.json
}
