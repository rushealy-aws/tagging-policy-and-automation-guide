# AWS Config Rules for Tag Compliance Monitoring
# Monitors compliance with mandatory tagging requirements

# Enable AWS Config (if not already enabled)
resource "aws_config_configuration_recorder" "main" {
  name     = "tag-compliance-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    
    resource_types = [
      "AWS::ECS::Cluster",
      "AWS::ECS::Service", 
      "AWS::Logs::LogGroup",
      "AWS::EC2::NatGateway",
      "AWS::ElasticLoadBalancingV2::LoadBalancer",
      "AWS::ElasticLoadBalancingV2::TargetGroup"
    ]
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "tag-compliance-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
}

# S3 bucket for Config
resource "aws_s3_bucket" "config_bucket" {
  bucket        = "aws-config-tag-compliance-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "compliance"
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config_bucket.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config_bucket.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Required Tags Config Rule
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

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "compliance"
  }
}

# ECS-specific tag compliance rule
resource "aws_config_config_rule" "ecs_required_tags" {
  name = "ecs-required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "Owner"
    tag3Key = "CostCenter"
    tag4Key = "Application"
    tag5Key = "OS"
  })

  scope {
    compliance_resource_types = [
      "AWS::ECS::Cluster",
      "AWS::ECS::Service"
    ]
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "compliance"
  }
}

# CloudWatch resources tag compliance
resource "aws_config_config_rule" "cloudwatch_required_tags" {
  name = "cloudwatch-required-tags"

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

  scope {
    compliance_resource_types = [
      "AWS::Logs::LogGroup"
    ]
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "compliance"
  }
}

# IAM role for Config
resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "compliance"
  }
}

resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# CloudWatch alarm for compliance violations
resource "aws_cloudwatch_metric_alarm" "tag_compliance_alarm" {
  alarm_name          = "tag-compliance-violations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ComplianceByConfigRule"
  namespace           = "AWS/Config"
  period              = "300"
  statistic           = "Average"
  threshold           = "1.0"
  alarm_description   = "This metric monitors tag compliance violations"
  alarm_actions       = [aws_sns_topic.compliance_alerts.arn]

  dimensions = {
    ConfigRuleName = aws_config_config_rule.required_tags.name
  }

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "monitoring"
  }
}

# SNS topic for compliance alerts
resource "aws_sns_topic" "compliance_alerts" {
  name = "tag-compliance-alerts"

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "monitoring"
  }
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Outputs
output "config_rules" {
  description = "List of created Config rules"
  value = [
    aws_config_config_rule.required_tags.name,
    aws_config_config_rule.ecs_required_tags.name,
    aws_config_config_rule.cloudwatch_required_tags.name
  ]
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for compliance alerts"
  value       = aws_sns_topic.compliance_alerts.arn
}
