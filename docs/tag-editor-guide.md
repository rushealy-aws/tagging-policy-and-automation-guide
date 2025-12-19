# AWS Tag Editor Guide

## Overview

AWS Tag Editor is a centralized service for finding, viewing, and managing tags across multiple AWS resources and regions. This guide provides step-by-step instructions for using Tag Editor to implement your tagging strategy, with a focus on high-cost resources.

## Prerequisites

- AWS Management Console access
- Appropriate IAM permissions for tagging resources
- Understanding of your [tagging strategy](tagging-strategy.md)

## Required IAM Permissions

Ensure your IAM user/role has these permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "tag:GetResources",
                "tag:TagResources",
                "tag:UntagResources",
                "resource-groups:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Getting Started with Tag Editor

### Accessing Tag Editor
1. Sign in to the AWS Management Console
2. Navigate to **Resource Groups & Tag Editor**
3. Select **Tag Editor** from the left navigation

## Finding Resources to Tag

### Step 1: Select Regions
1. Choose the AWS regions where your resources are located
2. For multi-region deployments, select all relevant regions
3. **Recommendation**: Start with your primary region (e.g., us-east-1)

### Step 2: Choose Resource Types

#### For High-Cost Resources (Priority Order):

**ECS Resources (Highest Priority - $800/month)**
- `AWS::ECS::Cluster`
- `AWS::ECS::Service`
- `AWS::ECS::TaskDefinition`

**CloudWatch Resources**
- `AWS::Logs::LogGroup`
- `AWS::CloudWatch::Dashboard`
- `AWS::CloudWatch::Alarm`

**Networking Resources**
- `AWS::EC2::NatGateway`
- `AWS::ElasticLoadBalancingV2::LoadBalancer`
- `AWS::ElasticLoadBalancingV2::TargetGroup`

### Step 3: Filter by Existing Tags (Optional)
- Leave empty to find all resources of selected types
- Use filters to find untagged resources: select "(empty value)" for tag values
- Use filters to find specific resources: enter tag key/value pairs

### Step 4: Execute Search
1. Click **Search resources**
2. Review results in the Resource search results table
3. Use the **Filter resources** field to narrow results further

## Bulk Tagging Operations

### Adding Tags to Multiple Resources

1. **Select Resources**
   - Use checkboxes to select resources for tagging
   - Select up to 500 resources at once
   - Use "Select all" for bulk operations

2. **Manage Tags**
   - Click **Manage tags of selected resources**
   - Review existing tags on selected resources

3. **Add Required Tags**
   ```
   Environment = prod
   Owner = platform-team
   CostCenter = eng-001
   Application = customer-portal
   ```

4. **Apply Changes**
   - Review tag changes in the summary
   - Click **Apply changes to all selected**
   - Wait for the operation to complete (green success banner)

### Editing Existing Tags

1. **Find Resources with Specific Tags**
   - Search for resources with the tag you want to modify
   - Example: Find all resources with `Environment = dev`

2. **Bulk Edit Tag Values**
   - Select resources to modify
   - Choose **Manage tags of selected resources**
   - Modify the tag value (e.g., change `dev` to `development`)
   - Apply changes

### Removing Tags

1. **Select Resources**
   - Find resources with tags you want to remove
   - Select the resources

2. **Remove Tags**
   - Choose **Manage tags of selected resources**
   - Click the **X** next to tags you want to remove
   - Apply changes

## Priority Implementation Workflow

### Phase 1: ECS Infrastructure (Week 1)

1. **Find ECS Clusters**
   ```
   Resource Types: AWS::ECS::Cluster
   Regions: [Your regions]
   Tags: (empty to find all)
   ```

2. **Tag ECS Clusters**
   - Add mandatory tags to all clusters
   - Include `OS=linux` for patch management

3. **Find ECS Services**
   ```
   Resource Types: AWS::ECS::Service
   ```

4. **Tag ECS Services**
   - Apply application-specific tags
   - Include environment designation

### Phase 2: CloudWatch Resources (Week 2)

1. **Find Log Groups**
   ```
   Resource Types: AWS::Logs::LogGroup
   ```

2. **Tag by Application**
   - Group log groups by application
   - Apply consistent tagging

3. **Find CloudWatch Dashboards**
   ```
   Resource Types: AWS::CloudWatch::Dashboard
   ```

### Phase 3: Networking Infrastructure (Week 3)

1. **Find NAT Gateways**
   ```
   Resource Types: AWS::EC2::NatGateway
   ```

2. **Find Load Balancers**
   ```
   Resource Types: AWS::ElasticLoadBalancingV2::LoadBalancer
   ```

## Advanced Tag Editor Features

### Exporting Results
1. After running a search, click **Export** 
2. Download CSV file with resource details and current tags
3. Use for offline analysis and planning

### Filtering Large Result Sets
- Use the **Filter resources** field for substring matching
- Filter by resource name, ID, or other attributes
- Combine with tag filters for precise targeting

### Column Configuration
1. Click the **Preferences** gear icon
2. Configure visible columns
3. Show/hide specific tag columns
4. Adjust rows per page display

## Best Practices for Tag Editor

### Planning Your Tagging Sessions
1. **Start Small**: Begin with one resource type at a time
2. **Test First**: Try tagging a few resources before bulk operations
3. **Document Changes**: Keep track of what you've tagged
4. **Verify Results**: Check that tags were applied correctly

### Efficient Bulk Operations
1. **Group Similar Resources**: Tag resources with similar characteristics together
2. **Use Consistent Values**: Copy/paste tag values to ensure consistency
3. **Batch by Region**: Complete one region before moving to the next
4. **Monitor Progress**: Watch for success/failure messages

### Error Handling
- **Permission Errors**: Verify IAM permissions for specific resource types
- **Resource Limits**: Tag Editor supports up to 500 resources per operation
- **Service Limits**: Some services have tag limits (typically 50 tags per resource)
- **Retry Failed Operations**: Re-run operations that partially failed

## Monitoring Tag Compliance

### Finding Untagged Resources
1. **Search All Resource Types**
   ```
   Resource Types: All resource types
   Tags: (leave empty)
   ```

2. **Filter Results**
   - Look for resources with 0 tags in the Tags column
   - Export results for compliance reporting

### Validating Tag Values
1. **Search by Tag Key**
   ```
   Tags: Environment = (leave value empty)
   ```

2. **Review Tag Values**
   - Check for inconsistent values (e.g., "prod" vs "production")
   - Standardize values using bulk edit operations

## Integration with Cost Management

After tagging resources with Tag Editor:

1. **Activate Cost Allocation Tags** (see [Billing Tags Guide](billing-tags-guide.md))
2. **Generate Cost Reports** filtered by your new tags
3. **Create Cost Budgets** based on tag combinations
4. **Monitor Spending** by Environment, Owner, and Application

## Troubleshooting Common Issues

### Resources Not Appearing in Search
- **Check Regions**: Ensure you've selected the correct regions
- **Verify Resource Types**: Some resources may not support tagging
- **IAM Permissions**: Confirm you have read permissions for the resource type

### Tag Changes Not Applied
- **Resource Limits**: Check if resource already has 50 tags
- **Service Restrictions**: Some services have tagging limitations
- **Permissions**: Verify write permissions for the specific resource type

### Inconsistent Tag Values
- **Case Sensitivity**: Tag values are case-sensitive
- **Whitespace**: Remove leading/trailing spaces
- **Special Characters**: Avoid special characters in tag values

## Next Steps

1. Complete bulk tagging of priority resources using this guide
2. Set up [Cost Allocation Tags](billing-tags-guide.md) for financial tracking
3. Implement [Automation](automation-guide.md) for ongoing compliance
4. Regular audits using Tag Editor to maintain tag hygiene
