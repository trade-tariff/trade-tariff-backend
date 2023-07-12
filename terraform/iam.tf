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
      data.aws_secretsmanager_secret.redis_connection_string.arn,
      data.aws_secretsmanager_secret.newrelic_license_key.arn,
      data.aws_secretsmanager_secret.backend_secret_key_base.arn,
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

resource "aws_iam_policy" "secrets" {
  name   = "backend-execution-role-secrets-policy"
  policy = data.aws_iam_policy_document.secrets.json
}