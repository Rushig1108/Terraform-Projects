# AWS Instance Scheduler

This Terraform project automatically manages AWS EC2 instances to reduce costs by starting and stopping non-production instances based on working hours.

## Features

- **Automatic Scheduling**: Start EC2 instances at the beginning of the workday and stop them after hours
- **Override Protection**: Tag instances with `ScheduleOverride: true` to exempt them from automatic scheduling
- **Cost Management**: Identify untagged resources that may be contributing to unexpected AWS costs
- **Notifications**: Receive alerts via email and Slack when instances are started/stopped or when untagged resources are found

## Repository Structure

```
aws-instance-scheduler/
├── terraform/          # Terraform configuration files
├── lambda/             # Lambda function source code
├── scripts/            # Deployment and utility scripts
└── README.md           # This file
```

## Prerequisites

- Terraform 1.0.0 or newer
- AWS CLI configured with appropriate permissions
- Python 3.9 or newer (for local development of Lambda functions)

## Setup Instructions

1. **Prepare Lambda packages:**

   ```bash
   cd scripts
   ./build_lambda.sh
   ```

   This will create the necessary ZIP files in the `terraform/lambda_packages/` directory.

2. **Configure the variables:**

   Edit `terraform.tfvars` to set your email address, Slack webhook URL, and other parameters.

3. **Initialize Terraform:**

   ```bash
   terraform init
   ```

4. **Deploy the infrastructure:**

   ```bash
   terraform apply
   ```

5. **Tag your non-production instances:**

   Add the tag `AutoStop: true` to any EC2 instances you want to be automatically started and stopped.

## Usage

### Automatic Scheduling

- Instances tagged with `AutoStop: true` will automatically:
  - Start at the configured time each working day (default: 8 AM Monday-Friday)
  - Stop at the configured time each working day (default: 6 PM Monday-Friday)

### Override Tag

When you need an instance to remain running overnight (for testing, batch jobs, etc.):

1. Add the tag `ScheduleOverride: true` to the instance
2. Remove or set to `false` when normal scheduling should resume

### Untagged Resources Report

Every day at the configured time (default: 9 AM), the system will:

1. Scan for resources missing the required cost-allocation tags
2. Calculate estimated monthly costs for these resources
3. Send a report via email and Slack

## Customization

- Modify working hours by changing `working_hours_start` and `working_hours_end` variables
- Adjust the timezone by setting the `timezone` variable
- Customize required tags by modifying the `required_tags` variable

## Cleanup

To remove all created resources:

```bash
terraform destroy
```
