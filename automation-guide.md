# AWS Tagging Automation Guide

## Overview

This guide provides comprehensive automation strategies for implementing and maintaining your AWS tagging strategy using Terraform, AWS Config, and other automation tools. Focus is on preventing untagged resources and ensuring consistent tag application.

## Automation Approaches

### 1. Infrastructure as Code (Terraform)
- Embed tags in resource definitions
- Use modules for consistent tag application
- Implement tag validation

### 2. Policy-Based Enforcement (AWS Organizations)
- Tag policies to enforce required tags
- Service Control Policies (SCPs) to prevent untagged resources
- Preventive controls

### 3. Reactive Automation (AWS Config + Lambda)
- Detect untagged resources
- Automatically apply missing tags
- Compliance monitoring and remediation

## Terraform Implementation

### Standard Tagging Module

Create a reusable tagging module:

```hcl
# modules/common-tags/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition = contains(["prod", "dev", "test", "qa", "staging"], var.environment)
    error_message = "Environment must be one of: prod, dev, test, qa, staging."
  }
}

variable "owner" {
  description = "Team or department responsible for the resource"
  type        = string
}

variable "cost_center" {
  description = "Cost center or budget code"
  type        = string
}

variable "application" {
  description = "Application or workload name"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/common-tags/main.tf
locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Application = var.application
    ManagedBy   = "terraform"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
  
  all_tags = merge(local.common_tags, var.additional_tags)
}
```

```hcl
# modules/common-tags/outputs.tf
output "tags" {
  description = "Common tags to be applied to resources"
  value       = local.all_tags
}

output "tags_asg" {
  description = "Tags formatted for Auto Scaling Groups"
  value = [
    for key, value in local.all_tags : {
      key                 = key
      value               = value
      propagate_at_launch = true
    }
  ]
}
```

### ECS Service Example

```hcl
# environments/prod/ecs.tf
module "common_tags" {
  source = "../../modules/common-tags"
  
  environment  = "prod"
  owner       = "platform-team"
  cost_center = "eng-001"
  application = "customer-portal"
  
  additional_tags = {
    OS          = "linux"
    Backup      = "required"
    Criticality = "high"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "customer-portal-prod"
  
  tags = module.common_tags.tags
}

resource "aws_ecs_service" "app" {
  name            = "customer-portal-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 3
  
  tags = merge(module.common_tags.tags, {
    ServiceType = "web-application"
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "customer-portal-app"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  
  tags = module.common_tags.tags
  
  container_definitions = jsonencode([
    {
      name  = "app"
      image = "customer-portal:latest"
      # ... container configuration
    }
  ])
}
```

### CloudWatch Resources Example

```hcl
# modules/cloudwatch-logging/main.tf
variable "application_name" {
  description = "Application name for log group"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ecs/${var.application_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = merge(var.tags, {
    LogType = "application"
    Service = "ecs"
  })
}

resource "aws_cloudwatch_dashboard" "app_dashboard" {
  dashboard_name = "${var.application_name}-${var.environment}-dashboard"
  
  tags = merge(var.tags, {
    DashboardType = "application"
  })
  
  dashboard_body = jsonencode({
    widgets = [
      # Dashboard configuration
    ]
  })
}
```

### Load Balancer Example

```hcl
# modules/alb/main.tf
resource "aws_lb" "main" {
  name               = "${var.application_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets           = var.subnet_ids
  
  tags = merge(var.tags, {
    LoadBalancerType = "application"
    Scheme          = "internet-facing"
  })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.application_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  tags = merge(var.tags, {
    TargetType = "ecs-service"
  })
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
}
```

## AWS Organizations Tag Policies

### Comprehensive Tag Policy

```json
{
  "tags": {
    "Environment": {
      "tag_key": {
        "@@assign": "Environment"
      },
      "tag_value": {
        "@@assign": [
          "prod",
          "dev", 
          "test",
          "qa",
          "staging"
        ]
      },
      "enforced_for": {
        "@@assign": [
          "all"
        ]
      }
    },
    "Owner": {
      "tag_key": {
        "@@assign": "Owner"
      },
      "tag_value": {
        "@@assign": [
          "platform-team",
          "data-team",
          "security-team",
          "finance-team"
        ]
      },
      "enforced_for": {
        "@@assign": [
          "all"
        ]
      }
    },
    "CostCenter": {
      "tag_key": {
        "@@assign": "CostCenter"
      },
      "tag_value": {
        "@@assign": [
          "eng-*",
          "ops-*",
          "finance-*"
        ]
      },
      "enforced_for": {
        "@@assign": [
          "all"
        ]
      }
    },
    "Application": {
      "tag_key": {
        "@@assign": "Application"
      },
      "enforced_for": {
        "@@assign": [
          "all"
        ]
      }
    }
  }
}
```

### Service Control Policy for Tag Enforcement

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequireTagsOnECSResources",
      "Effect": "Deny",
      "Action": [
        "ecs:CreateCluster",
        "ecs:CreateService",
        "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestedRegion": "false"
        },
        "ForAnyValue:StringNotEquals": {
          "aws:TagKeys": [
            "Environment",
            "Owner",
            "CostCenter", 
            "Application"
          ]
        }
      }
    },
    {
      "Sid": "RequireTagsOnCloudWatchResources",
      "Effect": "Deny",
      "Action": [
        "logs:CreateLogGroup",
        "cloudwatch:PutDashboard"
      ],
      "Resource": "*",
      "Condition": {
        "ForAnyValue:StringNotEquals": {
          "aws:TagKeys": [
            "Environment",
            "Owner",
            "CostCenter",
            "Application"
          ]
        }
      }
    }
  ]
}
```

## AWS Config Automation

### Required Tags Config Rule

```hcl
# terraform/config-rules/required-tags.tf
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags-compliance"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "Owner"
    tag3Key = "CostCenter"
    tag4Key = "Application"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_remediation_configuration" "required_tags" {
  config_rule_name = aws_config_config_rule.required_tags.name

  resource_type    = "AWS::EC2::Instance"
  target_type      = "SSM_DOCUMENT"
  target_id        = aws_ssm_document.tag_remediation.name
  target_version   = "1"

  parameter {
    name           = "AutomationAssumeRole"
    static_value   = aws_iam_role.config_remediation.arn
  }

  parameter {
    name             = "InstanceId"
    resource_value   = "RESOURCE_ID"
  }

  automatic                = true
  maximum_automatic_attempts = 3
}
```

### Lambda Function for Auto-Tagging

```python
# lambda/auto-tagger/lambda_function.py
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Auto-tag resources based on Config rule evaluation
    """
    
    # Parse Config rule evaluation
    config_item = event['configurationItem']
    resource_type = config_item['resourceType']
    resource_id = config_item['resourceId']
    
    # Default tags to apply
    default_tags = {
        'Environment': 'unknown',
        'Owner': 'unassigned',
        'CostCenter': 'unassigned',
        'Application': 'unassigned',
        'AutoTagged': 'true'
    }
    
    try:
        # Apply tags based on resource type
        if resource_type == 'AWS::ECS::Cluster':
            tag_ecs_cluster(resource_id, default_tags)
        elif resource_type == 'AWS::ECS::Service':
            tag_ecs_service(resource_id, default_tags)
        elif resource_type == 'AWS::Logs::LogGroup':
            tag_log_group(resource_id, default_tags)
        elif resource_type == 'AWS::ElasticLoadBalancingV2::LoadBalancer':
            tag_load_balancer(resource_id, default_tags)
            
        logger.info(f"Successfully tagged {resource_type}: {resource_id}")
        
    except Exception as e:
        logger.error(f"Failed to tag {resource_type}: {resource_id}, Error: {str(e)}")
        raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Tagged {resource_type}: {resource_id}')
    }

def tag_ecs_cluster(cluster_name, tags):
    """Tag ECS cluster"""
    ecs = boto3.client('ecs')
    
    # Get cluster ARN
    response = ecs.describe_clusters(clusters=[cluster_name])
    cluster_arn = response['clusters'][0]['clusterArn']
    
    # Apply tags
    ecs.tag_resource(
        resourceArn=cluster_arn,
        tags=[{'key': k, 'value': v} for k, v in tags.items()]
    )

def tag_ecs_service(service_arn, tags):
    """Tag ECS service"""
    ecs = boto3.client('ecs')
    
    ecs.tag_resource(
        resourceArn=service_arn,
        tags=[{'key': k, 'value': v} for k, v in tags.items()]
    )

def tag_log_group(log_group_name, tags):
    """Tag CloudWatch log group"""
    logs = boto3.client('logs')
    
    logs.tag_log_group(
        logGroupName=log_group_name,
        tags=tags
    )

def tag_load_balancer(lb_arn, tags):
    """Tag Application Load Balancer"""
    elbv2 = boto3.client('elbv2')
    
    elbv2.add_tags(
        ResourceArns=[lb_arn],
        Tags=[{'Key': k, 'Value': v} for k, v in tags.items()]
    )
```

### Terraform for Lambda Auto-Tagger

```hcl
# terraform/lambda/auto-tagger.tf
resource "aws_lambda_function" "auto_tagger" {
  filename         = "auto-tagger.zip"
  function_name    = "aws-auto-tagger"
  role            = aws_iam_role.auto_tagger.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "auto-tagger"
  }
}

resource "aws_lambda_permission" "config_invoke" {
  statement_id  = "AllowConfigInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_tagger.function_name
  principal     = "config.amazonaws.com"
}

resource "aws_iam_role" "auto_tagger" {
  name = "auto-tagger-role"

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

resource "aws_iam_role_policy" "auto_tagger" {
  name = "auto-tagger-policy"
  role = aws_iam_role.auto_tagger.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:TagResource",
          "ecs:DescribeClusters",
          "logs:TagLogGroup",
          "elasticloadbalancing:AddTags"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## Monitoring and Alerting

### CloudWatch Dashboard for Tag Compliance

```hcl
# terraform/monitoring/tag-compliance-dashboard.tf
resource "aws_cloudwatch_dashboard" "tag_compliance" {
  dashboard_name = "tag-compliance-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", "required-tags-compliance"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Tag Compliance Over Time"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Config", "ComplianceByResourceType", "ResourceType", "AWS::ECS::Cluster"],
            [".", ".", ".", "AWS::ECS::Service"],
            [".", ".", ".", "AWS::Logs::LogGroup"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Compliance by Resource Type"
          period  = 300
        }
      }
    ]
  })

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "monitoring"
  }
}
```

### SNS Alerts for Non-Compliance

```hcl
# terraform/monitoring/compliance-alerts.tf
resource "aws_sns_topic" "tag_compliance_alerts" {
  name = "tag-compliance-alerts"

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "monitoring"
  }
}

resource "aws_cloudwatch_metric_alarm" "tag_compliance" {
  alarm_name          = "tag-compliance-violation"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ComplianceByConfigRule"
  namespace           = "AWS/Config"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.95"
  alarm_description   = "This metric monitors tag compliance"
  alarm_actions       = [aws_sns_topic.tag_compliance_alerts.arn]

  dimensions = {
    ConfigRuleName = "required-tags-compliance"
  }

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "monitoring"
  }
}
```

## Automation Scripts

### Bulk Tagging Script

```bash
#!/bin/bash
# scripts/bulk-tagging.sh

set -e

# Configuration
REGION="us-east-1"
ENVIRONMENT="prod"
OWNER="platform-team"
COST_CENTER="eng-001"

# Function to tag ECS clusters
tag_ecs_clusters() {
    echo "Tagging ECS clusters..."
    
    # Get all cluster ARNs
    CLUSTERS=$(aws ecs list-clusters --region $REGION --query 'clusterArns[]' --output text)
    
    for CLUSTER_ARN in $CLUSTERS; do
        echo "Tagging cluster: $CLUSTER_ARN"
        
        aws ecs tag-resource \
            --region $REGION \
            --resource-arn $CLUSTER_ARN \
            --tags key=Environment,value=$ENVIRONMENT \
                   key=Owner,value=$OWNER \
                   key=CostCenter,value=$COST_CENTER \
                   key=Application,value=ecs-cluster \
                   key=OS,value=linux
    done
}

# Function to tag CloudWatch log groups
tag_log_groups() {
    echo "Tagging CloudWatch log groups..."
    
    # Get all log groups
    LOG_GROUPS=$(aws logs describe-log-groups --region $REGION --query 'logGroups[].logGroupName' --output text)
    
    for LOG_GROUP in $LOG_GROUPS; do
        echo "Tagging log group: $LOG_GROUP"
        
        # Determine application from log group name
        if [[ $LOG_GROUP == *"ecs"* ]]; then
            APPLICATION="ecs-application"
        elif [[ $LOG_GROUP == *"lambda"* ]]; then
            APPLICATION="lambda-function"
        else
            APPLICATION="unknown"
        fi
        
        aws logs tag-log-group \
            --region $REGION \
            --log-group-name $LOG_GROUP \
            --tags Environment=$ENVIRONMENT,Owner=$OWNER,CostCenter=$COST_CENTER,Application=$APPLICATION
    done
}

# Function to tag NAT gateways
tag_nat_gateways() {
    echo "Tagging NAT gateways..."
    
    # Get all NAT gateway IDs
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region $REGION --query 'NatGateways[].NatGatewayId' --output text)
    
    for NAT_GW in $NAT_GATEWAYS; do
        echo "Tagging NAT gateway: $NAT_GW"
        
        aws ec2 create-tags \
            --region $REGION \
            --resources $NAT_GW \
            --tags Key=Environment,Value=$ENVIRONMENT \
                   Key=Owner,Value=$OWNER \
                   Key=CostCenter,Value=$COST_CENTER \
                   Key=Application,Value=networking
    done
}

# Main execution
echo "Starting bulk tagging process..."
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "Owner: $OWNER"
echo "Cost Center: $COST_CENTER"
echo ""

tag_ecs_clusters
tag_log_groups
tag_nat_gateways

echo "Bulk tagging completed!"
```

### Tag Audit Script

```python
#!/usr/bin/env python3
# scripts/tag-audit.py

import boto3
import csv
import json
from datetime import datetime

class TagAuditor:
    def __init__(self, region='us-east-1'):
        self.region = region
        self.required_tags = ['Environment', 'Owner', 'CostCenter', 'Application']
        
    def audit_ecs_resources(self):
        """Audit ECS clusters and services"""
        ecs = boto3.client('ecs', region_name=self.region)
        results = []
        
        # Audit clusters
        clusters = ecs.list_clusters()['clusterArns']
        for cluster_arn in clusters:
            tags = ecs.list_tags_for_resource(resourceArn=cluster_arn)['tags']
            tag_dict = {tag['key']: tag['value'] for tag in tags}
            
            compliance = self.check_compliance(tag_dict)
            results.append({
                'ResourceType': 'ECS::Cluster',
                'ResourceId': cluster_arn.split('/')[-1],
                'ResourceArn': cluster_arn,
                'Compliant': compliance['compliant'],
                'MissingTags': ','.join(compliance['missing_tags']),
                'ExistingTags': json.dumps(tag_dict)
            })
            
        # Audit services
        for cluster_arn in clusters:
            services = ecs.list_services(cluster=cluster_arn)['serviceArns']
            for service_arn in services:
                tags = ecs.list_tags_for_resource(resourceArn=service_arn)['tags']
                tag_dict = {tag['key']: tag['value'] for tag in tags}
                
                compliance = self.check_compliance(tag_dict)
                results.append({
                    'ResourceType': 'ECS::Service',
                    'ResourceId': service_arn.split('/')[-1],
                    'ResourceArn': service_arn,
                    'Compliant': compliance['compliant'],
                    'MissingTags': ','.join(compliance['missing_tags']),
                    'ExistingTags': json.dumps(tag_dict)
                })
                
        return results
    
    def audit_cloudwatch_resources(self):
        """Audit CloudWatch log groups"""
        logs = boto3.client('logs', region_name=self.region)
        results = []
        
        paginator = logs.get_paginator('describe_log_groups')
        for page in paginator.paginate():
            for log_group in page['logGroups']:
                log_group_name = log_group['logGroupName']
                
                try:
                    tags_response = logs.list_tags_log_group(logGroupName=log_group_name)
                    tag_dict = tags_response.get('tags', {})
                    
                    compliance = self.check_compliance(tag_dict)
                    results.append({
                        'ResourceType': 'Logs::LogGroup',
                        'ResourceId': log_group_name,
                        'ResourceArn': f"arn:aws:logs:{self.region}:*:log-group:{log_group_name}",
                        'Compliant': compliance['compliant'],
                        'MissingTags': ','.join(compliance['missing_tags']),
                        'ExistingTags': json.dumps(tag_dict)
                    })
                except Exception as e:
                    print(f"Error auditing log group {log_group_name}: {e}")
                    
        return results
    
    def check_compliance(self, tags):
        """Check if resource has all required tags"""
        missing_tags = []
        for required_tag in self.required_tags:
            if required_tag not in tags or not tags[required_tag]:
                missing_tags.append(required_tag)
                
        return {
            'compliant': len(missing_tags) == 0,
            'missing_tags': missing_tags
        }
    
    def generate_report(self, output_file='tag_audit_report.csv'):
        """Generate comprehensive audit report"""
        all_results = []
        
        print("Auditing ECS resources...")
        all_results.extend(self.audit_ecs_resources())
        
        print("Auditing CloudWatch resources...")
        all_results.extend(self.audit_cloudwatch_resources())
        
        # Write to CSV
        with open(output_file, 'w', newline='') as csvfile:
            fieldnames = ['ResourceType', 'ResourceId', 'ResourceArn', 'Compliant', 'MissingTags', 'ExistingTags']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for result in all_results:
                writer.writerow(result)
        
        # Print summary
        total_resources = len(all_results)
        compliant_resources = sum(1 for r in all_results if r['Compliant'])
        compliance_rate = (compliant_resources / total_resources) * 100 if total_resources > 0 else 0
        
        print(f"\nAudit Summary:")
        print(f"Total Resources: {total_resources}")
        print(f"Compliant Resources: {compliant_resources}")
        print(f"Compliance Rate: {compliance_rate:.1f}%")
        print(f"Report saved to: {output_file}")

if __name__ == "__main__":
    auditor = TagAuditor()
    auditor.generate_report()
```

## Best Practices for Automation

### 1. Gradual Rollout
- Start with development environments
- Test automation thoroughly before production
- Implement rollback procedures

### 2. Monitoring and Alerting
- Set up compliance monitoring
- Alert on policy violations
- Track automation effectiveness

### 3. Documentation and Training
- Document all automation procedures
- Train teams on new processes
- Maintain runbooks for troubleshooting

### 4. Regular Reviews
- Review automation effectiveness monthly
- Update policies based on learnings
- Refine tag strategies based on usage

## Next Steps

1. **Implement Terraform Modules**: Start with the common tags module
2. **Deploy Config Rules**: Set up compliance monitoring
3. **Create Lambda Functions**: Implement auto-tagging for new resources
4. **Set Up Monitoring**: Deploy compliance dashboards and alerts
5. **Test and Refine**: Continuously improve automation based on results

This automation approach ensures consistent tagging while reducing manual effort and improving compliance across your AWS environment.
