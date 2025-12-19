# AWS Systems Manager Patch Management Using Tags

## Overview

AWS Systems Manager Patch Manager automates the process of patching managed instances with security-related and other updates. This guide demonstrates how to use tags to organize instances into patch groups, enabling targeted patching strategies based on environment, operating system, and criticality.

## Prerequisites

- AWS Systems Manager configured with managed instances
- SSM Agent installed on EC2 instances or hybrid instances
- IAM permissions for Systems Manager operations
- Instances tagged according to your [tagging strategy](tagging-strategy.md)

## Understanding Patch Groups

### What are Patch Groups?

Patch groups allow you to associate managed instances with specific patch baselines. This ensures:
- Appropriate patches are deployed to the correct instances
- Patches are tested before production deployment
- Different environments follow different patching schedules

### Key Concepts

- **Patch Baseline**: Rules for auto-approving patches and lists of approved/rejected patches
- **Patch Group**: Collection of instances tagged with `PatchGroup` or `Patch Group`
- **Maintenance Window**: Scheduled time for patching operations
- **Patch Compliance**: Status indicating whether instances have required patches installed

## Tag-Based Patch Group Strategy

### Required Tags for Patch Management

Based on your tagging strategy, use these tags for patch management:

| Tag Key | Purpose | Example Values |
|---------|---------|----------------|
| `os` | Operating system type | `linux`, `windows`, `amazon-linux`, `ubuntu` |
| `environment` | SDLC stage | `prod`, `dev`, `test`, `qa` |
| `PatchGroup` | Patch group assignment | `prod-linux`, `dev-windows`, `qa-amazon-linux` |

### Patch Group Naming Convention

Combine environment and OS for patch group names:
```
Format: {environment}-{os}

Examples:
- prod-linux
- dev-windows
- test-amazon-linux
- qa-ubuntu
```

## Implementation Steps

### Step 1: Tag Instances for Patch Groups

#### Using AWS Console

1. **Navigate to EC2 Console**
   - Select instances to tag
   - Choose **Actions** → **Instance Settings** → **Manage Tags**

2. **Add Patch Group Tag**
   ```
   Key: PatchGroup
   Value: prod-linux
   ```

3. **Verify Existing Tags**
   - Ensure `os` and `environment` tags are present
   - These support your patch group strategy

#### Using AWS CLI

```bash
# Tag EC2 instances for production Linux patch group
aws ec2 create-tags \
    --resources i-1234567890abcdef0 i-0987654321fedcba0 \
    --tags Key=PatchGroup,Value=prod-linux \
           Key=os,Value=linux \
           Key=environment,Value=prod

# Tag development Windows instances
aws ec2 create-tags \
    --resources i-abcdef1234567890 \
    --tags Key=PatchGroup,Value=dev-windows \
           Key=os,Value=windows \
           Key=environment,Value=dev
```

#### Bulk Tagging Script

```bash
#!/bin/bash
# Tag instances by environment and OS

REGION="us-east-1"

# Get all Linux instances in production
PROD_LINUX_INSTANCES=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:environment,Values=prod" \
              "Name=tag:os,Values=linux" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

# Tag them with patch group
for INSTANCE in $PROD_LINUX_INSTANCES; do
    aws ec2 create-tags \
        --region $REGION \
        --resources $INSTANCE \
        --tags Key=PatchGroup,Value=prod-linux
done
```

### Step 2: Create Patch Baselines

#### Production Linux Baseline

```bash
aws ssm create-patch-baseline \
    --name "prod-linux-baseline" \
    --description "Production Linux patch baseline with 7-day approval delay" \
    --operating-system "AMAZON_LINUX_2" \
    --approval-rules "PatchRules=[{
        PatchFilterGroup={
            PatchFilters=[
                {Key=CLASSIFICATION,Values=[Security,Bugfix]},
                {Key=SEVERITY,Values=[Critical,Important]}
            ]
        },
        ApproveAfterDays=7,
        ComplianceLevel=CRITICAL
    }]" \
    --tags Key=environment,Value=prod \
           Key=owner,Value=platform-team \
           Key=costcenter,Value=eng-001
```

#### Development Linux Baseline

```bash
aws ssm create-patch-baseline \
    --name "dev-linux-baseline" \
    --description "Development Linux patch baseline with immediate approval" \
    --operating-system "AMAZON_LINUX_2" \
    --approval-rules "PatchRules=[{
        PatchFilterGroup={
            PatchFilters=[
                {Key=CLASSIFICATION,Values=[Security,Bugfix,Enhancement]},
                {Key=SEVERITY,Values=[Critical,Important,Medium]}
            ]
        },
        ApproveAfterDays=0,
        ComplianceLevel=MEDIUM
    }]" \
    --tags Key=environment,Value=dev \
           Key=owner,Value=platform-team
```

### Step 3: Register Patch Groups with Baselines

```bash
# Register production Linux patch group
aws ssm register-patch-baseline-for-patch-group \
    --baseline-id pb-0c10e65780EXAMPLE \
    --patch-group prod-linux

# Register development Linux patch group
aws ssm register-patch-baseline-for-patch-group \
    --baseline-id pb-9876543210EXAMPLE \
    --patch-group dev-linux

# Verify registration
aws ssm describe-patch-groups
```

### Step 4: Create Maintenance Windows

#### Production Maintenance Window

```bash
# Create maintenance window for production (Sunday 2 AM)
aws ssm create-maintenance-window \
    --name "prod-linux-patching" \
    --description "Production Linux patching window" \
    --schedule "cron(0 2 ? * SUN *)" \
    --duration 4 \
    --cutoff 1 \
    --allow-unassociated-targets \
    --tags Key=environment,Value=prod \
           Key=owner,Value=platform-team

# Register targets using patch group tag
aws ssm register-target-with-maintenance-window \
    --window-id mw-0c50858d01EXAMPLE \
    --target-type INSTANCE \
    --resource-type INSTANCE \
    --targets "Key=tag:PatchGroup,Values=prod-linux"

# Register patching task
aws ssm register-task-with-maintenance-window \
    --window-id mw-0c50858d01EXAMPLE \
    --target-id e32eecb2-646c-4f4b-8ed1-205fbEXAMPLE \
    --task-type RUN_COMMAND \
    --task-arn "AWS-RunPatchBaseline" \
    --service-role-arn arn:aws:iam::123456789012:role/MaintenanceWindowRole \
    --task-invocation-parameters "RunCommand={Parameters={Operation=Install}}" \
    --priority 1 \
    --max-concurrency 50% \
    --max-errors 1
```

#### Development Maintenance Window

```bash
# Create maintenance window for development (Daily 10 PM)
aws ssm create-maintenance-window \
    --name "dev-linux-patching" \
    --description "Development Linux patching window" \
    --schedule "cron(0 22 * * ? *)" \
    --duration 2 \
    --cutoff 0 \
    --allow-unassociated-targets \
    --tags Key=environment,Value=dev

# Register targets and tasks (similar to production)
```

## Patch Group Strategies by Environment

### Production Environment
- **Patch Group**: `prod-linux`, `prod-windows`
- **Approval Delay**: 7 days (allow time for testing)
- **Schedule**: Weekly (Sunday 2 AM)
- **Severity**: Critical and Important only
- **Reboot**: Controlled, during maintenance window

### Development Environment
- **Patch Group**: `dev-linux`, `dev-windows`
- **Approval Delay**: 0 days (immediate)
- **Schedule**: Daily (10 PM)
- **Severity**: All severities
- **Reboot**: Automatic if needed

### Test/QA Environment
- **Patch Group**: `test-linux`, `qa-linux`
- **Approval Delay**: 3 days
- **Schedule**: Twice weekly (Tuesday, Thursday)
- **Severity**: Critical, Important, Medium
- **Reboot**: Automatic if needed

## On-Demand Patching

### Patch Specific Instances

```bash
# Scan for missing patches
aws ssm send-command \
    --document-name "AWS-RunPatchBaseline" \
    --targets "Key=tag:PatchGroup,Values=prod-linux" \
    --parameters "Operation=Scan" \
    --comment "Scan production Linux instances for patches"

# Install patches on specific patch group
aws ssm send-command \
    --document-name "AWS-RunPatchBaseline" \
    --targets "Key=tag:PatchGroup,Values=dev-linux" \
    --parameters "Operation=Install" \
    --comment "Install patches on development Linux instances"
```

### Emergency Patching

```bash
# Patch critical instances immediately
aws ssm send-command \
    --document-name "AWS-RunPatchBaseline" \
    --targets "Key=InstanceIds,Values=i-1234567890abcdef0" \
    --parameters "Operation=Install,RebootOption=RebootIfNeeded" \
    --comment "Emergency security patch"
```

## Monitoring Patch Compliance

### View Compliance by Patch Group

```bash
# Get compliance summary for patch group
aws ssm describe-instance-patch-states \
    --instance-ids $(aws ec2 describe-instances \
        --filters "Name=tag:PatchGroup,Values=prod-linux" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)

# Get detailed patch compliance
aws ssm describe-patch-group-state \
    --patch-group prod-linux
```

### Compliance Dashboard

Use AWS Systems Manager console:
1. Navigate to **Patch Manager**
2. Choose **Compliance reporting**
3. Filter by patch group tag
4. View compliance status and missing patches

## Best Practices

### 1. Patch Group Organization
- Use consistent naming: `{environment}-{os}`
- One patch group per instance
- Align with your tagging strategy

### 2. Baseline Configuration
- Production: Conservative (7-day delay, critical only)
- Development: Aggressive (immediate, all patches)
- Test: Moderate (3-day delay, critical + important)

### 3. Maintenance Windows
- Production: Low-traffic periods (weekends)
- Development: Daily during off-hours
- Stagger windows to avoid resource contention

### 4. Testing Strategy
```
Development → Test → QA → Production
(Day 0)      (Day 3) (Day 5) (Day 7)
```

### 5. Compliance Monitoring
- Set up CloudWatch alarms for non-compliant instances
- Generate weekly compliance reports
- Review and remediate non-compliant instances

## Automation with Terraform

### Patch Baseline Resource

```hcl
resource "aws_ssm_patch_baseline" "prod_linux" {
  name             = "prod-linux-baseline"
  description      = "Production Linux patch baseline"
  operating_system = "AMAZON_LINUX_2"

  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  tags = {
    environment = "prod"
    owner      = "platform-team"
    costcenter = "eng-001"
  }
}

resource "aws_ssm_patch_group" "prod_linux" {
  baseline_id = aws_ssm_patch_baseline.prod_linux.id
  patch_group = "prod-linux"
}
```

### Maintenance Window Resource

```hcl
resource "aws_ssm_maintenance_window" "prod_linux" {
  name              = "prod-linux-patching"
  description       = "Production Linux patching window"
  schedule          = "cron(0 2 ? * SUN *)"
  duration          = 4
  cutoff            = 1
  allow_unassociated_targets = false

  tags = {
    environment = "prod"
    owner      = "platform-team"
  }
}

resource "aws_ssm_maintenance_window_target" "prod_linux" {
  window_id     = aws_ssm_maintenance_window.prod_linux.id
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["prod-linux"]
  }
}

resource "aws_ssm_maintenance_window_task" "prod_linux_patch" {
  window_id        = aws_ssm_maintenance_window.prod_linux.id
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.maintenance_window.arn
  max_concurrency  = "50%"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.prod_linux.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}
```

## Troubleshooting

### Instances Not Receiving Patches
- Verify `PatchGroup` tag is applied correctly
- Check SSM Agent is running and up to date
- Confirm instance has IAM role with SSM permissions
- Verify patch group is registered with a baseline

### Patch Baseline Not Applied
- Ensure only one patch group per instance
- Verify patch group matches registered baseline
- Check maintenance window targets include the patch group

### Compliance Reporting Issues
- Allow 24 hours for compliance data to populate
- Verify SSM Agent can communicate with Systems Manager
- Check CloudWatch Logs for SSM Agent errors

## Next Steps

1. **Tag Your Instances**: Apply `PatchGroup` tags based on environment and OS
2. **Create Baselines**: Set up patch baselines for each environment
3. **Register Groups**: Associate patch groups with baselines
4. **Schedule Patching**: Create maintenance windows for automated patching
5. **Monitor Compliance**: Set up dashboards and alerts for patch compliance

For more information on your overall tagging strategy, see [Tagging Strategy](tagging-strategy.md).

## References

### AWS Documentation
- [AWS Systems Manager Patch Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html)
- [Patch Groups](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-patch-groups.html)
- [Creating and Managing Patch Groups](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-tag-a-patch-group.html)
- [AWS-RunPatchBaseline Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-aws-runpatchbaseline.html)
- [Maintenance Windows](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-maintenance.html)

### Related Guides
- [Patching Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/patching.html)
- [Systems Manager Prerequisites](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-prereqs.html)
