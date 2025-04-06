# start_instances.py
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
sns = boto3.client('sns')

# Environment variables
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
TIMEZONE = os.environ.get('TIMEZONE', 'UTC')

def lambda_handler(event, context):
    """
    Start EC2 instances that have the tag 'AutoStop' set to 'true'.
    Skip instances that have 'ScheduleOverride' set to 'true'.
    """
    logger.info("Starting EC2 instances with 'AutoStop: true' tag")
    
    # Get current time in the specified timezone
    tz = pytz.timezone(TIMEZONE)
    current_time = datetime.now(tz)
    
    # Format time for notifications
    formatted_time = current_time.strftime("%Y-%m-%d %H:%M:%S %Z")
    
    # Find instances with AutoStop=true and not currently running
    instances_to_start = []
    
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:AutoStop',
                'Values': ['true', 'True', 'yes', 'Yes']
            },
            {
                'Name': 'instance-state-name',
                'Values': ['stopped']
            }
        ]
    )
    
    # Process the response
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            
            # Check for override tag
            skip_instance = False
            for tag in instance.get('Tags', []):
                if tag['Key'] == 'ScheduleOverride' and tag['Value'].lower() in ['true', 'yes']:
                    logger.info(f"Skipping instance {instance_id} due to ScheduleOverride tag")
                    skip_instance = True
                    break
            
            if skip_instance:
                continue
                
            # Add instance to list to start
            instances_to_start.append(instance_id)
    
    if not instances_to_start:
        logger.info("No instances found that need to be started")
        return {
            'statusCode': 200,
            'body': json.dumps('No instances to start')
        }
    
    # Start the instances
    logger.info(f"Starting instances: {instances_to_start}")
    ec2.start_instances(InstanceIds=instances_to_start)
    
    # Create notification message
    message = f"EC2 Instance Scheduler - Started {len(instances_to_start)} instances at {formatted_time}\n"
    message += f"Instances: {', '.join(instances_to_start)}"
    
    # Send SNS notification
    logger.info("Sending SNS notification")
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="EC2 Instances Started",
        Message=message
    )
    
    # Send Slack notification
    try:
        send_slack_notification("EC2 Instances Started", message)
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Started {len(instances_to_start)} instances')
    }

def send_slack_notification(title, message):
    """Send notification to Slack channel"""
    payload = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": title
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": message
                }
            }
        ]
    }
    
    response = requests.post(
        SLACK_WEBHOOK_URL,
        data=json.dumps(payload),
        headers={'Content-Type': 'application/json'}
    )
    
    if response.status_code != 200:
        raise ValueError(f"Error sending Slack notification: {response.status_code}, {response.text}")