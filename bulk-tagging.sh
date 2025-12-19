#!/bin/bash

# AWS Bulk Tagging Script
# This script applies mandatory tags to high-cost AWS resources
# Focus: ECS, CloudWatch, NAT Gateways, and Load Balancers

set -e

# Configuration - Modify these values for your environment
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
OWNER="${OWNER:-platform-team}"
COST_CENTER="${COST_CENTER:-eng-001}"
APPLICATION="${APPLICATION:-customer-portal}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    log_success "AWS CLI is configured and working"
}

# Function to validate required parameters
validate_parameters() {
    if [[ -z "$REGION" || -z "$ENVIRONMENT" || -z "$OWNER" || -z "$COST_CENTER" ]]; then
        log_error "Missing required parameters. Please set REGION, ENVIRONMENT, OWNER, and COST_CENTER"
        exit 1
    fi
    
    # Validate environment value
    if [[ ! "$ENVIRONMENT" =~ ^(prod|dev|test|qa|staging)$ ]]; then
        log_error "ENVIRONMENT must be one of: prod, dev, test, qa, staging"
        exit 1
    fi
    
    log_info "Parameters validated successfully"
}

# Function to tag ECS clusters
tag_ecs_clusters() {
    log_info "Tagging ECS clusters in region: $REGION"
    
    # Get all cluster ARNs
    CLUSTERS=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[]' --output text 2>/dev/null || true)
    
    if [[ -z "$CLUSTERS" ]]; then
        log_warning "No ECS clusters found in region $REGION"
        return 0
    fi
    
    local cluster_count=0
    for CLUSTER_ARN in $CLUSTERS; do
        CLUSTER_NAME=$(echo "$CLUSTER_ARN" | cut -d'/' -f2)
        log_info "Tagging ECS cluster: $CLUSTER_NAME"
        
        if aws ecs tag-resource \
            --region "$REGION" \
            --resource-arn "$CLUSTER_ARN" \
            --tags key=Environment,value="$ENVIRONMENT" \
                   key=Owner,value="$OWNER" \
                   key=CostCenter,value="$COST_CENTER" \
                   key=Application,value="$APPLICATION" \
                   key=OS,value=linux \
                   key=ManagedBy,value=bulk-tagging-script \
            2>/dev/null; then
            log_success "Tagged ECS cluster: $CLUSTER_NAME"
            ((cluster_count++))
        else
            log_error "Failed to tag ECS cluster: $CLUSTER_NAME"
        fi
    done
    
    log_success "Tagged $cluster_count ECS clusters"
}

# Function to tag ECS services
tag_ecs_services() {
    log_info "Tagging ECS services in region: $REGION"
    
    # Get all cluster ARNs first
    CLUSTERS=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[]' --output text 2>/dev/null || true)
    
    if [[ -z "$CLUSTERS" ]]; then
        log_warning "No ECS clusters found for service tagging"
        return 0
    fi
    
    local service_count=0
    for CLUSTER_ARN in $CLUSTERS; do
        CLUSTER_NAME=$(echo "$CLUSTER_ARN" | cut -d'/' -f2)
        
        # Get services in this cluster
        SERVICES=$(aws ecs list-services --region "$REGION" --cluster "$CLUSTER_ARN" --query 'serviceArns[]' --output text 2>/dev/null || true)
        
        for SERVICE_ARN in $SERVICES; do
            SERVICE_NAME=$(echo "$SERVICE_ARN" | cut -d'/' -f3)
            log_info "Tagging ECS service: $SERVICE_NAME in cluster: $CLUSTER_NAME"
            
            if aws ecs tag-resource \
                --region "$REGION" \
                --resource-arn "$SERVICE_ARN" \
                --tags key=Environment,value="$ENVIRONMENT" \
                       key=Owner,value="$OWNER" \
                       key=CostCenter,value="$COST_CENTER" \
                       key=Application,value="$APPLICATION" \
                       key=ServiceType,value=web-application \
                       key=ManagedBy,value=bulk-tagging-script \
                2>/dev/null; then
                log_success "Tagged ECS service: $SERVICE_NAME"
                ((service_count++))
            else
                log_error "Failed to tag ECS service: $SERVICE_NAME"
            fi
        done
    done
    
    log_success "Tagged $service_count ECS services"
}

# Function to tag CloudWatch log groups
tag_log_groups() {
    log_info "Tagging CloudWatch log groups in region: $REGION"
    
    # Get all log groups (handle pagination)
    local log_group_count=0
    local next_token=""
    
    while true; do
        if [[ -n "$next_token" ]]; then
            RESPONSE=$(aws logs describe-log-groups --region "$REGION" --next-token "$next_token" --output json 2>/dev/null || echo '{"logGroups":[]}')
        else
            RESPONSE=$(aws logs describe-log-groups --region "$REGION" --output json 2>/dev/null || echo '{"logGroups":[]}')
        fi
        
        # Extract log group names
        LOG_GROUPS=$(echo "$RESPONSE" | jq -r '.logGroups[].logGroupName' 2>/dev/null || true)
        
        for LOG_GROUP in $LOG_GROUPS; do
            log_info "Tagging log group: $LOG_GROUP"
            
            # Determine application from log group name
            local app_name="$APPLICATION"
            if [[ "$LOG_GROUP" == *"ecs"* ]]; then
                app_name="ecs-application"
            elif [[ "$LOG_GROUP" == *"lambda"* ]]; then
                app_name="lambda-function"
            elif [[ "$LOG_GROUP" == *"api"* ]]; then
                app_name="api-gateway"
            fi
            
            if aws logs tag-log-group \
                --region "$REGION" \
                --log-group-name "$LOG_GROUP" \
                --tags Environment="$ENVIRONMENT",Owner="$OWNER",CostCenter="$COST_CENTER",Application="$app_name",LogType=application,ManagedBy=bulk-tagging-script \
                2>/dev/null; then
                log_success "Tagged log group: $LOG_GROUP"
                ((log_group_count++))
            else
                log_error "Failed to tag log group: $LOG_GROUP"
            fi
        done
        
        # Check for next token
        next_token=$(echo "$RESPONSE" | jq -r '.nextToken // empty' 2>/dev/null || true)
        if [[ -z "$next_token" ]]; then
            break
        fi
    done
    
    log_success "Tagged $log_group_count CloudWatch log groups"
}

# Function to tag NAT gateways
tag_nat_gateways() {
    log_info "Tagging NAT gateways in region: $REGION"
    
    # Get all NAT gateway IDs
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region "$REGION" --query 'NatGateways[?State==`available`].NatGatewayId' --output text 2>/dev/null || true)
    
    if [[ -z "$NAT_GATEWAYS" ]]; then
        log_warning "No NAT gateways found in region $REGION"
        return 0
    fi
    
    local nat_count=0
    for NAT_GW in $NAT_GATEWAYS; do
        log_info "Tagging NAT gateway: $NAT_GW"
        
        if aws ec2 create-tags \
            --region "$REGION" \
            --resources "$NAT_GW" \
            --tags Key=Environment,Value="$ENVIRONMENT" \
                   Key=Owner,Value="$OWNER" \
                   Key=CostCenter,Value="$COST_CENTER" \
                   Key=Application,Value=networking \
                   Key=ResourceType,Value=nat-gateway \
                   Key=ManagedBy,Value=bulk-tagging-script \
            2>/dev/null; then
            log_success "Tagged NAT gateway: $NAT_GW"
            ((nat_count++))
        else
            log_error "Failed to tag NAT gateway: $NAT_GW"
        fi
    done
    
    log_success "Tagged $nat_count NAT gateways"
}

# Function to tag Application Load Balancers
tag_load_balancers() {
    log_info "Tagging Application Load Balancers in region: $REGION"
    
    # Get all ALB ARNs
    ALB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text 2>/dev/null || true)
    
    if [[ -z "$ALB_ARNS" ]]; then
        log_warning "No Application Load Balancers found in region $REGION"
        return 0
    fi
    
    local alb_count=0
    for ALB_ARN in $ALB_ARNS; do
        ALB_NAME=$(echo "$ALB_ARN" | cut -d'/' -f2)
        log_info "Tagging ALB: $ALB_NAME"
        
        if aws elbv2 add-tags \
            --region "$REGION" \
            --resource-arns "$ALB_ARN" \
            --tags Key=Environment,Value="$ENVIRONMENT" \
                   Key=Owner,Value="$OWNER" \
                   Key=CostCenter,Value="$COST_CENTER" \
                   Key=Application,Value="$APPLICATION" \
                   Key=LoadBalancerType,Value=application \
                   Key=ManagedBy,Value=bulk-tagging-script \
            2>/dev/null; then
            log_success "Tagged ALB: $ALB_NAME"
            ((alb_count++))
        else
            log_error "Failed to tag ALB: $ALB_NAME"
        fi
    done
    
    log_success "Tagged $alb_count Application Load Balancers"
}

# Function to tag Target Groups
tag_target_groups() {
    log_info "Tagging Target Groups in region: $REGION"
    
    # Get all Target Group ARNs
    TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null || true)
    
    if [[ -z "$TG_ARNS" ]]; then
        log_warning "No Target Groups found in region $REGION"
        return 0
    fi
    
    local tg_count=0
    for TG_ARN in $TG_ARNS; do
        TG_NAME=$(echo "$TG_ARN" | cut -d'/' -f2)
        log_info "Tagging Target Group: $TG_NAME"
        
        if aws elbv2 add-tags \
            --region "$REGION" \
            --resource-arns "$TG_ARN" \
            --tags Key=Environment,Value="$ENVIRONMENT" \
                   Key=Owner,Value="$OWNER" \
                   Key=CostCenter,Value="$COST_CENTER" \
                   Key=Application,Value="$APPLICATION" \
                   Key=TargetType,Value=ecs-service \
                   Key=ManagedBy,Value=bulk-tagging-script \
            2>/dev/null; then
            log_success "Tagged Target Group: $TG_NAME"
            ((tg_count++))
        else
            log_error "Failed to tag Target Group: $TG_NAME"
        fi
    done
    
    log_success "Tagged $tg_count Target Groups"
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION        AWS region (default: us-east-1)"
    echo "  -e, --environment ENV      Environment (prod|dev|test|qa|staging)"
    echo "  -o, --owner OWNER          Owner/team name (default: platform-team)"
    echo "  -c, --cost-center CENTER   Cost center code (default: eng-001)"
    echo "  -a, --application APP      Application name (default: customer-portal)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION                 AWS region"
    echo "  ENVIRONMENT                Environment name"
    echo "  OWNER                      Owner/team name"
    echo "  COST_CENTER                Cost center code"
    echo "  APPLICATION                Application name"
    echo ""
    echo "Examples:"
    echo "  $0 --region us-west-2 --environment prod --owner platform-team"
    echo "  ENVIRONMENT=dev OWNER=dev-team $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -o|--owner)
            OWNER="$2"
            shift 2
            ;;
        -c|--cost-center)
            COST_CENTER="$2"
            shift 2
            ;;
        -a|--application)
            APPLICATION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "=========================================="
    echo "AWS Bulk Tagging Script"
    echo "=========================================="
    echo "Region: $REGION"
    echo "Environment: $ENVIRONMENT"
    echo "Owner: $OWNER"
    echo "Cost Center: $COST_CENTER"
    echo "Application: $APPLICATION"
    echo "=========================================="
    echo ""
    
    # Validate prerequisites
    check_aws_cli
    validate_parameters
    
    # Confirm before proceeding
    read -p "Do you want to proceed with bulk tagging? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    
    local start_time=$(date +%s)
    
    # Execute tagging functions
    tag_ecs_clusters
    tag_ecs_services
    tag_log_groups
    tag_nat_gateways
    tag_load_balancers
    tag_target_groups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "=========================================="
    log_success "Bulk tagging completed successfully!"
    log_info "Total execution time: ${duration} seconds"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Verify tags using AWS Tag Editor or run tag-audit.py"
    echo "2. Activate cost allocation tags in AWS Billing console"
    echo "3. Set up AWS Config rules for ongoing compliance monitoring"
    echo "4. Generate cost reports filtered by your new tags"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
