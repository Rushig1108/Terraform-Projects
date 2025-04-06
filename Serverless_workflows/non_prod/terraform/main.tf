# main.tf - Main configuration for the AWS Instance Scheduler

# IAM Role for Lambda functions
resource "aws_iam_role" "instance_scheduler_role" {
  name = "instance-scheduler-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to manage EC2 instances
resource "aws_iam_policy" "ec2_management_policy" {
  name        = "ec2-management-policy-${var.environment}"
  description = "Policy to allow Lambda to manage EC2 instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for checking untagged resources
resource "aws_iam_policy" "resource_checker_policy" {
  name        = "resource-checker-policy-${var.environment}"
  description = "Policy to allow checking untagged resources"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeAddresses",
          "ec2:DescribeTags",
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "lambda_ec2_policy_attachment" {
  role       = aws_iam_role.instance_scheduler_role.name
  policy_arn = aws_iam_policy.ec2_management_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_resource_checker_attachment" {
  role       = aws_iam_role.instance_scheduler_role.name
  policy_arn = aws_iam_policy.resource_checker_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.instance_scheduler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS Topic for notifications
resource "aws_sns_topic" "instance_scheduler_notifications" {
  name = "instance-scheduler-notifications-${var.environment}"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.instance_scheduler_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Log Group for Lambda functions
resource "aws_cloudwatch_log_group" "start_instances_logs" {
  name              = "/aws/lambda/start-tagged-instances-${var.environment}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "stop_instances_logs" {
  name              = "/aws/lambda/stop-tagged-instances-${var.environment}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "untagged_resources_logs" {
  name              = "/aws/lambda/untagged-resources-checker-${var.environment}"
  retention_in_days = var.log_retention_days
}

# Lambda function for starting instances
resource "aws_lambda_function" "start_instances" {
  function_name    = "start-tagged-instances-${var.environment}"
  role             = aws_iam_role.instance_scheduler_role.arn
  handler          = "start_instances.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  filename         = "${path.module}/lambda_packages/start_instances.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_packages/start_instances.zip")
  
  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.instance_scheduler_notifications.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      TIMEZONE         = var.timezone
      REQUIRED_TAGS    = jsonencode(var.required_tags)
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.start_instances_logs,
    aws_iam_role_policy_attachment.lambda_ec2_policy_attachment
  ]
}

# Lambda function for stopping instances
resource "aws_lambda_function" "stop_instances" {
  function_name    = "stop-tagged-instances-${var.environment}"
  role             = aws_iam_role.instance_scheduler_role.arn
  handler          = "stop_instances.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  filename         = "${path.module}/lambda_packages/stop_instances.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_packages/stop_instances.zip")
  
  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.instance_scheduler_notifications.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      TIMEZONE         = var.timezone
      REQUIRED_TAGS    = jsonencode(var.required_tags)
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.stop_instances_logs,
    aws_iam_role_policy_attachment.lambda_ec2_policy_attachment
  ]
}

# Lambda function for identifying untagged resources
resource "aws_lambda_function" "untagged_resources_checker" {
  function_name    = "untagged-resources-checker-${var.environment}"
  role             = aws_iam_role.instance_scheduler_role.arn
  handler          = "untagged_resources.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = 120  # More time needed for resource scanning
  memory_size      = var.lambda_memory_size
  
  filename         = "${path.module}/lambda_packages/untagged_resources.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_packages/untagged_resources.zip")
  
  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.instance_scheduler_notifications.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      REQUIRED_TAGS    = jsonencode(var.required_tags)
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.untagged_resources_logs,
    aws_iam_role_policy_attachment.lambda_resource_checker_attachment
  ]
}

# EventBridge rule for starting instances on working days
resource "aws_cloudwatch_event_rule" "start_instances_rule" {
  name                = "start-instances-rule-${var.environment}"
  description         = "Start tagged EC2 instances during working hours"
  schedule_expression = "cron(0 ${var.working_hours_start} ? * MON-FRI *)"  # Runs at configured time Mon-Fri
}

resource "aws_cloudwatch_event_target" "start_instances_target" {
  rule      = aws_cloudwatch_event_rule.start_instances_rule.name
  target_id = "start_instances_lambda"
  arn       = aws_lambda_function.start_instances.arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances_rule.arn
}

# EventBridge rule for stopping instances after working hours
resource "aws_cloudwatch_event_rule" "stop_instances_rule" {
  name                = "stop-instances-rule-${var.environment}"
  description         = "Stop tagged EC2 instances after working hours"
  schedule_expression = "cron(0 ${var.working_hours_end} ? * MON-FRI *)"  # Runs at configured time Mon-Fri
}

resource "aws_cloudwatch_event_target" "stop_instances_target" {
  rule      = aws_cloudwatch_event_rule.stop_instances_rule.name
  target_id = "stop_instances_lambda"
  arn       = aws_lambda_function.stop_instances.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances_rule.arn
}

# EventBridge rule for checking untagged resources daily
resource "aws_cloudwatch_event_rule" "untagged_resources_rule" {
  name                = "untagged-resources-rule-${var.environment}"
  description         = "Check for untagged resources daily"
  schedule_expression = "cron(0 9 ? * * *)"  # Runs at 9 AM every day
}

resource "aws_cloudwatch_event_target" "untagged_resources_target" {
  rule      = aws_cloudwatch_event_rule.untagged_resources_rule.name
  target_id = "untagged_resources_lambda"
  arn       = aws_lambda_function.untagged_resources_checker.arn
}

resource "aws_lambda_permission" "allow_eventbridge_untagged" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.untagged_resources_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.untagged_resources_rule.arn
}