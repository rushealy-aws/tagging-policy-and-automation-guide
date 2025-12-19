# Example: ECS Infrastructure with Proper Tagging
# This example shows how to implement consistent tagging across ECS resources

# Local variables for common tags
locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Application = var.application_name
    ManagedBy   = "terraform"
    OS          = "linux"
  }
  
  # Additional tags for specific resource types
  ecs_tags = merge(local.common_tags, {
    Service = "ecs"
  })
  
  cloudwatch_tags = merge(local.common_tags, {
    Service = "cloudwatch"
  })
  
  networking_tags = merge(local.common_tags, {
    Service = "networking"
  })
}

# Variables
variable "environment" {
  description = "Environment name (prod, dev, test, qa, staging)"
  type        = string
  validation {
    condition     = contains(["prod", "dev", "test", "qa", "staging"], var.environment)
    error_message = "Environment must be one of: prod, dev, test, qa, staging."
  }
}

variable "owner" {
  description = "Team or department responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center or budget code"
  type        = string
  default     = "eng-001"
}

variable "application_name" {
  description = "Application or workload name"
  type        = string
  default     = "customer-portal"
}

variable "vpc_id" {
  description = "VPC ID for ECS resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS services"
  type        = list(string)
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.application_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled"
  }

  tags = local.ecs_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.application_name}-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = var.environment == "prod" ? 512 : 256
  memory                  = var.environment == "prod" ? 1024 : 512
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn          = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.application_name
      image = "${var.application_name}:latest"
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
    }
  ])

  tags = local.ecs_tags
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.application_name}-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.environment == "prod" ? 3 : 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.application_name
    container_port   = 80
  }

  depends_on = [aws_lb_listener.app]

  tags = merge(local.ecs_tags, {
    ServiceType = "web-application"
    Criticality = var.environment == "prod" ? "high" : "medium"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.application_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.cloudwatch_tags, {
    LogType = "application"
  })
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.application_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = merge(local.networking_tags, {
    LoadBalancerType = "application"
    Scheme          = "internet-facing"
  })
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "${var.application_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.networking_tags, {
    TargetType = "ecs-service"
  })
}

# Load Balancer Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = local.networking_tags
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${var.application_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.networking_tags, {
    Name = "${var.application_name}-${var.environment}-alb-sg"
    Type = "alb-security-group"
  })
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.application_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.networking_tags, {
    Name = "${var.application_name}-${var.environment}-ecs-sg"
    Type = "ecs-security-group"
  })
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.application_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.ecs_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.application_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.ecs_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "${var.application_name}-${var.environment}-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ECS Service Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = merge(local.cloudwatch_tags, {
    DashboardType = "application"
  })
}

# Data sources
data "aws_region" "current" {}

# Outputs
output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}
