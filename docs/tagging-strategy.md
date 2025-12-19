# AWS Tagging Strategy

## Executive Summary

This document defines a comprehensive tagging strategy for AWS resources across multiple accounts, focusing on cost optimization, operational excellence, and compliance. The strategy prioritizes high-cost resources and provides both mandatory and optional tags aligned with AWS best practices.

## Tagging Schema

### Mandatory Tags

All AWS resources must include these four mandatory tags:

| Tag Key | Purpose | Allowed Values | Example |
|---------|---------|----------------|---------|
| `environment` | SDLC stage identification | `prod`, `dev`, `test`, `qa`, `staging` | `environment=prod` |
| `owner` | Budget/operational responsibility | Department or team name | `owner=platform-team` |
| `costcenter` | Financial tracking | Budget code or department ID | `costcenter=eng-001` |
| `application` | Application/workload identification | Application name or ID | `application=customer-portal` |

### Optional Tags (Recommended)

| Tag Key | Purpose | Allowed Values | Example |
|---------|---------|----------------|---------|
| `os` | Operating system (for patch management) | `windows`, `linux`, `amazon-linux`, `ubuntu` | `os=amazon-linux` |
| `backup` | Backup requirement | `required`, `not-required`, `daily`, `weekly` | `backup=daily` |
| `dataclassification` | Data sensitivity level | `public`, `internal`, `confidential`, `restricted` | `dataclassification=internal` |
| `project` | Project or initiative | Project name or code | `project=migration-2024` |

## Tag Naming Conventions

- **Case**: Use lowercase for tag keys and values
- **Separators**: Use hyphens (-) to separate words
- **Length**: Keep tag keys under 128 characters, values under 256 characters
- **Special Characters**: Avoid spaces, use hyphens instead
- **Consistency**: Use the same format across all resources

### Examples of Proper Formatting
```
environment=prod
owner=platform-team
costcenter=eng-001
application=customer-portal
os=amazon-linux
```

## Priority Resource Types

Based on current AWS spend, focus tagging efforts on these high-cost resources:

### Tier 1 (Highest Priority - $800/month)
- **ECS Services and Tasks**
- **ECS Clusters**
- **EC2 Instances** (supporting ECS)

### Tier 2 (High Priority)
- **CloudWatch Log Groups**
- **CloudWatch Dashboards**
- **CloudWatch Alarms**
- **NAT Gateways**
- **Application Load Balancers**
- **Target Groups**

### Tier 3 (Medium Priority)
- **VPCs and Subnets**
- **Security Groups**
- **IAM Roles** (where applicable)
- **Lambda Functions**
- **RDS Instances**

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
1. Activate cost allocation tags in billing console
2. Create AWS Organizations tag policies
3. Tag Tier 1 resources (ECS infrastructure)

### Phase 2: Expansion (Week 3-4)
1. Tag Tier 2 resources (CloudWatch, networking)
2. Implement AWS Config rules for compliance
3. Set up automated tagging for new resources

### Phase 3: Optimization (Week 5-6)
1. Tag remaining resources (Tier 3)
2. Generate cost allocation reports
3. Refine tagging strategy based on insights

## Governance and Compliance

### Tag Policies
Use AWS Organizations tag policies to enforce mandatory tags:
- Prevent resource creation without required tags
- Standardize tag values across accounts
- Audit existing resources for compliance

### Monitoring
- AWS Config rules for tag compliance
- CloudWatch dashboards for tag coverage metrics
- Regular audits using Tag Editor and custom scripts

### Responsibilities
- **Cloud Platform Team**: Define and maintain tagging strategy
- **Development Teams**: Apply tags to application resources
- **Finance Team**: Monitor cost allocation and reporting
- **Security Team**: Ensure data classification tags are applied

## Cost Allocation Strategy

### Billing Tags Activation
1. Navigate to AWS Billing Console → Cost Allocation Tags
2. Activate these tags for cost reporting:
   - `environment`
   - `owner`
   - `costcenter`
   - `application`

### Cost Reporting
- Generate monthly cost allocation reports
- Use Cost Explorer with tag-based filtering
- Create budget alerts based on tag combinations
- Track cost trends by environment and application

## Automation Considerations

### Terraform Integration
```hcl
# Standard tags for all resources
locals {
  common_tags = {
    environment    = var.environment
    owner         = var.owner
    costcenter    = var.cost_center
    application   = var.application_name
  }
}
```

### AWS Config Rules
- `required-tags`: Ensure mandatory tags are present
- `tag-value-compliance`: Validate tag values against allowed list

## Best Practices

1. **Start Small**: Begin with mandatory tags on high-cost resources
2. **Be Consistent**: Use the same tag keys and value formats across all resources
3. **Avoid PII**: Never include personally identifiable information in tags
4. **Regular Reviews**: Audit and update tagging strategy quarterly
5. **Automation First**: Implement automated tagging for new resources
6. **Cost Focus**: Prioritize resources that drive the highest costs

## Tag Value Guidelines

### Environment Values
- `prod`: Production workloads
- `dev`: Development environment
- `test`: Testing environment
- `qa`: Quality assurance environment
- `staging`: Pre-production staging

### Owner Values
- Use team or department names
- Format: `team-name` (e.g., `platform-team`, `data-team`)
- Avoid individual names, use team/role instead

### Cost Center Values
- Use existing budget codes or department IDs
- Format: `dept-###` (e.g., `eng-001`, `ops-002`)
- Coordinate with finance team for proper codes

## Next Steps

1. Review and approve this tagging strategy
2. Begin with [Implementation Guide](implementation-guide.md)
3. Use [Tag Editor Guide](tag-editor-guide.md) for bulk operations
4. Set up [Billing Tags](billing-tags-guide.md) for cost tracking
5. Implement [Automation](automation-guide.md) for ongoing compliance
