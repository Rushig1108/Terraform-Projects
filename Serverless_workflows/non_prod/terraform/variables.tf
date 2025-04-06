# variables.tf - Input variables for the Terraform configuration

variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "notification_email" {
  description = "Email address to receive notifications"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
}

variable "timezone" {
  description = "Timezone for scheduler"
  type        = string
  default     = "UTC"
}

variable "working_days" {
  description = "Days when instances should be running"
  type        = list(string)
  default     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
}

variable "working_hours_start" {
  description = "Hour to start instances (24h format)"
  type        = number
  default     = 8  # 8 AM
}

variable "working_hours_end" {
  description = "Hour to stop instances (24h format)"
  type        = number
  default     = 18  # 6 PM
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 14
}

variable "required_tags" {
  description = "List of required tags for cost allocation"
  type        = list(string)
  default     = ["Environment", "Project", "Owner", "CostCenter"]
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Memory allocation for Lambda functions in MB"
  type        = number
  default     = 128
}

variable "lambda_source_dir" {
  description = "Base directory containing Lambda function code"
  type        = string
  default     = "../lambda"
}