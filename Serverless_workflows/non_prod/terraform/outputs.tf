# outputs.tf - Output values from the Terraform configuration

output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = aws_sns_topic.instance_scheduler_notifications.arn
}

output "start_lambda_arn" {
  description = "ARN of the Lambda function for starting instances"
  value       = aws_lambda_function.start_instances.arn
}

output "stop_lambda_arn" {
  description = "ARN of the Lambda function for stopping instances"
  value       = aws_lambda_function.stop_instances.arn
}

output "untagged_resources_lambda_arn" {
  description = "ARN of the Lambda function for checking untagged resources"
  value       = aws_lambda_function.untagged_resources_checker.arn
}

output "eventbridge_start_rule_arn" {
  description = "ARN of the EventBridge rule for starting instances"
  value       = aws_cloudwatch_event_rule.start_instances_rule.arn
}

output "eventbridge_stop_rule_arn" {
  description = "ARN of the EventBridge rule for stopping instances"
  value       = aws_cloudwatch_event_rule.stop_instances_rule.arn
}

output "lambda_role_arn" {
  description = "ARN of the IAM role used by the Lambda functions"
  value       = aws_iam_role.instance_scheduler_role.arn
}