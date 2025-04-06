# providers.tf - AWS provider configuration

provider "aws" {
  region = var.aws_region

  # Uncomment to use specific profile from AWS credentials file
  # profile = "your-profile-name"
  
  # Add default tags that will be applied to all resources
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "AWS-Instance-Scheduler"
      Environment = var.environment
    }
  }
}