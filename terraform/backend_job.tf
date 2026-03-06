module "backend-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.19.2"

  region = var.region

  service_name              = "backend-job"
  container_definition_kind = "job"
  container_command         = local.job_command
  service_count             = 0

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  cpu          = var.cpu
  memory       = var.memory

  task_role_policy_arns = [aws_iam_policy.task.arn]

  service_environment_config = local.backend_job_secret_env_vars

  enable_ecs_exec = true

  has_autoscaler = false
  max_capacity   = 1
  min_capacity   = 0

  sns_topic_arns = [data.aws_sns_topic.slack_topic.arn]
}

resource "aws_cloudwatch_event_rule" "database_backup" {
  name                = "backend-database-backup-${var.environment}"
  description         = "Triggers daily database backup for ${var.environment}"
  schedule_expression = "cron(0 23 * * ? *)"
}

resource "aws_cloudwatch_event_target" "database_backup" {
  rule     = aws_cloudwatch_event_rule.database_backup.name
  arn      = data.aws_ecs_cluster.this.arn
  role_arn = aws_iam_role.eventbridge_ecs.arn

  input = jsonencode({
    containerOverrides = [{
      name    = "backend-job"
      command = ["/bin/sh", "-c", "./bin/backup-database"]
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "S3_BUCKET", value = "trade-tariff-database-backups-${local.account_id}" },
        { name = "DATABASE_SECRET", value = var.database_backup_secret_name },
      ]
    }]
  })

  ecs_target {
    task_count          = 1
    task_definition_arn = data.aws_ecs_task_definition.backend_job.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = data.aws_subnets.private.ids
      security_groups  = [data.aws_security_group.this.id]
      assign_public_ip = false
    }
  }
}

resource "aws_cloudwatch_event_rule" "database_replication" {
  count = var.environment != "production" ? 1 : 0

  name                = "backend-database-replication-${var.environment}"
  description         = "Triggers weekday database replication for ${var.environment}"
  schedule_expression = "cron(30 23 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "database_replication" {
  count = var.environment != "production" ? 1 : 0

  rule     = aws_cloudwatch_event_rule.database_replication[0].name
  arn      = data.aws_ecs_cluster.this.arn
  role_arn = aws_iam_role.eventbridge_ecs.arn

  input = jsonencode({
    containerOverrides = [{
      name    = "backend-job"
      command = ["/bin/sh", "-c", "./bin/db-replicate"]
    }]
  })

  ecs_target {
    task_count          = 1
    task_definition_arn = data.aws_ecs_task_definition.backend_job.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = data.aws_subnets.private.ids
      security_groups  = [data.aws_security_group.this.id]
      assign_public_ip = false
    }
  }
}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_ecs" {
  name               = "backend-eventbridge-ecs-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eventbridge_run_task" {
  role       = aws_iam_role.eventbridge_ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

data "aws_iam_policy_document" "eventbridge_pass_role" {
  statement {
    actions = ["iam:PassRole"]
    resources = [
      module.backend-job.task_execution_role_arn,
      module.backend-job.task_role_arn,
    ]
  }
}

resource "aws_iam_policy" "eventbridge_pass_role" {
  name   = "backend-eventbridge-pass-role-${var.environment}"
  policy = data.aws_iam_policy_document.eventbridge_pass_role.json
}

resource "aws_iam_role_policy_attachment" "eventbridge_pass_role" {
  role       = aws_iam_role.eventbridge_ecs.name
  policy_arn = aws_iam_policy.eventbridge_pass_role.arn
}
