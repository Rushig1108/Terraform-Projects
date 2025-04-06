# untagged_resources.py
import boto3
import os
import json
import logging
import requests
from datetime import datetime
import pytz

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ec2 = boto3.client('ec2')
rds = boto3.client('rds')
sns = boto3.client('sns')
pricing = boto3.client('pricing', region_name='us-east-1')  # Pricing API only available in us-east-1 and ap-south-1

# Environment variables
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']

# Required cost allocation tags
REQUIRED_TAGS = ['Environment', 'Project', 'Owner', 'CostCenter']

def lambda_handler(event, context):
    """
    Check for AWS resources that are missing required cost allocation tags
    and estimate their monthly cost.
    """
    logger.info("Checking for untagged AWS resources")
    
    untagged_resources = []
    total_estimated_cost = 0
    
    # Check EC2 instances
    untagged_ec2, ec2_cost = check_untagged_ec2_instances()
    untagged_resources.extend(untagged_ec2)
    total_estimated_cost += ec2_cost
    
    # Check EBS volumes
    untagged_ebs, ebs_cost = check_untagged_ebs_volumes()
    untagged_resources.extend(untagged_ebs)
    total_estimated_cost += ebs_cost
    
    # Check Elastic IPs
    untagged_eips, eip_cost = check_untagged_elastic_ips()
    untagged_resources.extend(untagged_eips)
    total_estimated_cost += eip_cost
    
    # Check RDS instances
    untagged_rds, rds_cost = check_untagged_rds_instances()
    untagged_resources.extend(untagged_rds)
    total_estimated_cost += rds_cost
    
    if not untagged_resources:
        logger.info("No untagged resources found")
        return {
            'statusCode': 200,
            'body': json.dumps('No untagged resources found')
        }
    
    # Create notification message
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message = f"Untagged Resources Report - {current_time}\n\n"
    message += f"Found {len(untagged_resources)} resources missing required cost allocation tags.\n"
    message += f"Estimated monthly cost: ${total_estimated_cost:.2f}\n\n"
    message += "Resources missing tags:\n"
    
    for resource in untagged_resources:
        message += f"- {resource['Type']}: {resource['Id']} (${resource['EstimatedMonthlyCost']:.2f}/month)\n"
        message += f"  Missing tags: {', '.join(resource['MissingTags'])}\n"
    
    # Send SNS notification
    logger.info("Sending SNS notification")
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"Untagged Resources Report - ${total_estimated_cost:.2f}/month",
        Message=message
    )
    
    # Send Slack notification
    try:
        send_slack_notification(f"Untagged Resources - ${total_estimated_cost:.2f}/month", message)
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Found {len(untagged_resources)} untagged resources')
    }

def check_untagged_ec2_instances():
    """Check for EC2 instances missing required tags"""
    untagged_resources = []
    total_estimated_cost = 0
    
    response = ec2.describe_instances()
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            # Skip terminated instances
            if instance['State']['Name'] == 'terminated':
                continue
                
            instance_id = instance['InstanceId']
            instance_type = instance['InstanceType']
            
            # Get existing tags
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            
            # Check for missing required tags
            missing_tags = [tag for tag in REQUIRED_TAGS if tag not in tags]
            
            if missing_tags:
                # Estimate monthly cost (simplified)
                estimated_cost = estimate_ec2_cost(instance_type)
                total_estimated_cost += estimated_cost
                
                untagged_resources.append({
                    'Type': 'EC2 Instance',
                    'Id': instance_id,
                    'EstimatedMonthlyCost': estimated_cost,
                    'MissingTags': missing_tags
                })
    
    return untagged_resources, total_estimated_cost

def check_untagged_ebs_volumes():
    """Check for EBS volumes missing required tags"""
    untagged_resources = []
    total_estimated_cost = 0
    
    response = ec2.describe_volumes()
    
    for volume in response['Volumes']:
        volume_id = volume['VolumeId']
        volume_size = volume['Size']  # Size in GB
        volume_type = volume['VolumeType']
        
        # Get existing tags
        tags = {tag['Key']: tag['Value'] for tag in volume.get('Tags', [])}
        
        # Check for missing required tags
        missing_tags = [tag for tag in REQUIRED_TAGS if tag not in tags]
        
        if missing_tags:
            # Estimate monthly cost (simplified)
            estimated_cost = estimate_ebs_cost(volume_type, volume_size)
            total_estimated_cost += estimated_cost
            
            untagged_resources.append({
                'Type': 'EBS Volume',
                'Id': volume_id,
                'EstimatedMonthlyCost': estimated_cost,
                'MissingTags': missing_tags
            })
    
    return untagged_resources, total_estimated_cost

def check_untagged_elastic_ips():
    """Check for Elastic IPs missing required tags"""
    untagged_resources = []
    total_estimated_cost = 0
    
    response = ec2.describe_addresses()
    
    for eip in response['Addresses']:
        allocation_id = eip.get('AllocationId', 'Unknown')
        public_ip = eip.get('PublicIp', 'Unknown')
        
        # Check if the EIP is associated with an instance
        is_associated = 'InstanceId' in eip
        
        # Get existing tags
        tags = {tag['Key']: tag['Value'] for tag in eip.get('Tags', [])}
        
        # Check for missing required tags
        missing_tags = [tag for tag in REQUIRED_TAGS if tag not in tags]
        
        if missing_tags:
            # Elastic IPs are charged only when NOT associated with a running instance
            # Standard price is approximately $0.005 per hour for unused IPs
            if not is_associated:
                estimated_cost = 0.005 * 24 * 30  # $0.005 per hour * 24 hours * 30 days
            else:
                estimated_cost = 0
                
            total_estimated_cost += estimated_cost
            
            untagged_resources.append({
                'Type': 'Elastic IP',
                'Id': f"{public_ip} ({allocation_id})",
                'EstimatedMonthlyCost': estimated_cost,
                'MissingTags': missing_tags
            })
    
    return untagged_resources, total_estimated_cost

def check_untagged_rds_instances():
    """Check for RDS instances missing required tags"""
    untagged_resources = []
    total_estimated_cost = 0
    
    response = rds.describe_db_instances()
    
    for instance in response['DBInstances']:
        db_instance_id = instance['DBInstanceIdentifier']
        db_instance_class = instance['DBInstanceClass']
        storage_gb = instance['AllocatedStorage']
        
        # Get the ARN for the instance to retrieve tags
        arn = instance['DBInstanceArn']
        
        # Get existing tags
        tag_response = rds.list_tags_for_resource(ResourceName=arn)
        tags = {tag['Key']: tag['Value'] for tag in tag_response.get('TagList', [])}
        
        # Check for missing required tags
        missing_tags = [tag for tag in REQUIRED_TAGS if tag not in tags]
        
        if missing_tags:
            # Estimate monthly cost (simplified)
            estimated_cost = estimate_rds_cost(db_instance_class, storage_gb)
            total_estimated_cost += estimated_cost
            
            untagged_resources.append({
                'Type': 'RDS Instance',
                'Id': db_instance_id,
                'EstimatedMonthlyCost': estimated_cost,
                'MissingTags': missing_tags
            })
    
    return untagged_resources, total_estimated_cost

def estimate_ec2_cost(instance_type):
    """Provide a rough estimate of monthly EC2 cost based on instance type"""
    # These are very rough estimates for on-demand pricing
    instance_pricing = {
        't2.micro': 0.0116 * 24 * 30,
        't2.small': 0.023 * 24 * 30,
        't2.medium': 0.046 * 24 * 30,
        'm5.large': 0.096 * 24 * 30,
        'm5.xlarge': 0.192 * 24 * 30,
        'm5.2xlarge': 0.384 * 24 * 30,
        'c5.large': 0.085 * 24 * 30,
        'c5.xlarge': 0.17 * 24 * 30,
        'r5.large': 0.126 * 24 * 30,
        'r5.xlarge': 0.252 * 24 * 30
    }
    
    return instance_pricing.get(instance_type, 0.05 * 24 * 30)  # Default to $0.05/hr if type unknown

def estimate_ebs_cost(volume_type, size_gb):
    """Provide a rough estimate of monthly EBS cost"""
    # These are very rough estimates for pricing
    volume_pricing = {
        'gp2': 0.10 * size_gb,  # $0.10 per GB-month for gp2
        'gp3': 0.08 * size_gb,  # $0.08 per GB-month for gp3
        'io1': 0.125 * size_gb,  # $0.125 per GB-month for io1
        'st1': 0.045 * size_gb,  # $0.045 per GB-month for st1
        'sc1': 0.025 * size_gb,  # $