# AWS Billing and Cost Allocation Tags Guide

## Overview

Cost allocation tags enable you to track AWS costs by organizing your resources and analyzing spending patterns. This guide walks through activating cost allocation tags, generating reports, and using tags for cost optimization.

## Prerequisites

- Resources must be tagged with your [tagging strategy](tagging-strategy.md)
- Management account access (for AWS Organizations)
- Billing and Cost Management console access

## Understanding Cost Allocation Tags

### Tag Types
- **User-defined tags**: Tags you create and apply to resources
- **AWS-generated tags**: Automatically created by AWS services (e.g., `awsApplication`)

### Tag Activation Process
1. Apply tags to resources using [Tag Editor](tag-editor-guide.md)
2. Activate tag keys in Billing console (this guide)
3. Wait 24-48 hours for data to appear in reports
4. Generate cost allocation reports and use Cost Explorer

## Step-by-Step Activation Process

### Step 1: Access Billing Console

1. **Sign in to AWS Management Console**
   - Use management account credentials (required for Organizations)
   - Navigate to AWS Billing and Cost Management console
   - URL: https://console.aws.amazon.com/costmanagement/

2. **Navigate to Cost Allocation Tags**
   - In the left navigation pane, choose **Cost allocation tags**
   - You'll see two tabs: **AWS-generated tags** and **User-defined tags**

### Step 2: Activate User-Defined Tags

1. **Select User-Defined Tags Tab**
   - Click on the **User-defined tags** tab
   - You'll see a list of tag keys that have been applied to resources

2. **Identify Your Tag Keys**
   Look for these mandatory tag keys from your tagging strategy:
   - `Environment`
   - `Owner` 
   - `CostCenter`
   - `Application`

3. **Activate Tag Keys**
   - Select the checkboxes next to the tag keys you want to activate
   - Click **Activate** button
   - Confirm activation in the dialog box

### Step 3: Activate AWS-Generated Tags (Optional)

1. **Select AWS-Generated Tags Tab**
   - Click on the **AWS-generated tags** tab
   - Look for useful tags like:
     - `createdBy` - Shows which service created the resource
     - `awsApplication` - Automatically activated for Service Catalog AppRegistry

2. **Activate Relevant Tags**
   - Select desired AWS-generated tags
   - Click **Activate**

## Timing and Expectations

### Activation Timeline
- **Tag Key Appearance**: Up to 24 hours after applying tags to resources
- **Tag Activation**: Up to 24 hours after clicking "Activate"
- **Report Data**: Available 24-48 hours after activation
- **Total Time**: Allow 2-3 days for complete data availability

### Status Indicators
- **Active**: Tag is activated and will appear in cost reports
- **Inactive**: Tag exists but won't appear in cost reports
- **Processing**: Tag activation is in progress

## Generating Cost Allocation Reports

### Step 1: Configure Cost Allocation Report

1. **Navigate to Cost & Usage Reports**
   - In Billing console, choose **Cost & Usage Reports**
   - Click **Create report**

2. **Report Configuration**
   ```
   Report name: monthly-cost-allocation-by-tags
   Time granularity: Monthly
   Report versioning: Overwrite existing report
   Enable report data integration: Yes (for QuickSight)
   ```

3. **Content Configuration**
   - Include resource IDs: Yes
   - Enable support for Redshift: Yes (optional)
   - Enable support for QuickSight: Yes (optional)

4. **Delivery Options**
   - S3 bucket: Create or select existing bucket
   - Report path prefix: `cost-reports/`
   - Time granularity: Monthly
   - Report data integration: Enable for analysis tools

### Step 2: Access Cost Explorer

1. **Enable Cost Explorer**
   - Navigate to **Cost Explorer** in the Billing console
   - Click **Launch Cost Explorer** (if not already enabled)
   - Wait for data processing (can take 24 hours)

2. **Create Tag-Based Views**
   - Choose **Cost Explorer** → **Reports**
   - Select **Create new report**
   - Choose report type: **Cost and Usage**

## Using Tags for Cost Analysis

### Cost Explorer Filtering

1. **Filter by Environment**
   ```
   Group by: Tag → Environment
   Filter: Environment = prod, dev, test
   Time range: Last 3 months
   ```

2. **Filter by Application**
   ```
   Group by: Tag → Application
   Filter: Application = customer-portal, admin-dashboard
   Service: All services or specific (e.g., ECS, CloudWatch)
   ```

3. **Filter by Owner/Team**
   ```
   Group by: Tag → Owner
   Filter: Owner = platform-team, data-team
   Time range: Current month
   ```

### Sample Cost Analysis Queries

#### ECS Cost by Environment
```
Service: Amazon Elastic Container Service
Group by: Tag → Environment
Time range: Last month
Chart type: Bar chart
```

#### CloudWatch Costs by Application
```
Service: Amazon CloudWatch
Group by: Tag → Application  
Filter: Environment = prod
Time range: Last 3 months
```

#### NAT Gateway Costs by Cost Center
```
Service: Amazon Virtual Private Cloud
Usage type: NatGateway
Group by: Tag → CostCenter
Time range: Last month
```

## Setting Up Cost Budgets with Tags

### Step 1: Create Tagged Budget

1. **Navigate to Budgets**
   - In Billing console, choose **Budgets**
   - Click **Create budget**

2. **Budget Configuration**
   ```
   Budget type: Cost budget
   Budget name: prod-environment-monthly
   Period: Monthly
   Budget amount: $1000 (adjust based on your needs)
   ```

3. **Add Tag Filters**
   ```
   Filters:
   - Tag: Environment = prod
   - Service: Amazon Elastic Container Service (optional)
   ```

### Step 2: Set Up Alerts

1. **Alert Thresholds**
   ```
   Alert 1: 80% of budgeted amount
   Alert 2: 100% of budgeted amount
   Alert 3: 120% of budgeted amount (forecasted)
   ```

2. **Notification Settings**
   - Email recipients: Finance team, platform team
   - SNS topic: Optional for automated responses

## Cost Optimization Strategies

### Identify Cost Drivers

1. **High-Cost Resources by Tag**
   - Use Cost Explorer to identify expensive resources
   - Group by tag combinations (Environment + Application)
   - Focus on production workloads first

2. **Untagged Resource Costs**
   - Filter for resources without tags
   - Prioritize tagging high-cost untagged resources
   - Use Tag Editor to bulk tag expensive resources

### Environment-Based Analysis

1. **Development Environment Optimization**
   ```
   Filter: Environment = dev
   Analysis: Look for resources running 24/7
   Action: Implement scheduling for dev resources
   ```

2. **Production Cost Monitoring**
   ```
   Filter: Environment = prod
   Analysis: Monitor cost trends and spikes
   Action: Set up alerts for unusual spending
   ```

## Advanced Cost Allocation Features

### Backfill Cost Allocation Tags

If you need historical cost data with tags:

1. **Request Backfill**
   - Navigate to **Cost allocation tags**
   - Click **Backfill tags**
   - Select time range (up to 12 months)
   - Choose tag keys to backfill

2. **Backfill Considerations**
   - Only works for resources that had tags historically
   - Takes 24-48 hours to process
   - Can only request once every 24 hours

### API-Based Tag Activation

For bulk operations, use the AWS CLI:

```bash
# Activate multiple tags at once
aws ce update-cost-allocation-tags-status \
    --cost-allocation-tags-status \
    TagKey=Environment,Status=Active \
    TagKey=Owner,Status=Active \
    TagKey=CostCenter,Status=Active \
    TagKey=Application,Status=Active
```

## Monitoring and Maintenance

### Regular Review Process

1. **Monthly Tag Review**
   - Check for new tag keys that need activation
   - Review cost allocation report accuracy
   - Identify untagged high-cost resources

2. **Quarterly Strategy Review**
   - Analyze cost trends by tag
   - Adjust tagging strategy based on insights
   - Update budgets and alerts

### Cost Allocation Report Analysis

1. **Download Monthly Reports**
   - Access reports from configured S3 bucket
   - Import into Excel or BI tools for analysis
   - Look for cost trends and anomalies

2. **Key Metrics to Track**
   - Cost per environment (prod vs dev vs test)
   - Cost per application or workload
   - Cost per team/owner
   - Percentage of untagged costs

## Troubleshooting Common Issues

### Tags Not Appearing for Activation
- **Wait Time**: Allow 24 hours after applying tags
- **Resource Coverage**: Ensure tags are applied to billable resources
- **Permissions**: Verify billing console access

### Cost Data Not Showing
- **Activation Time**: Allow 24-48 hours after activation
- **Report Configuration**: Check Cost & Usage Report settings
- **Service Coverage**: Some services may not support cost allocation tags

### Inconsistent Cost Data
- **Tag Values**: Ensure consistent tag values (case-sensitive)
- **Resource Lifecycle**: Consider resource creation/deletion timing
- **Service Limitations**: Some services have tagging restrictions

## Integration with Other AWS Services

### AWS Cost Anomaly Detection
- Set up anomaly detection with tag-based filtering
- Get alerts for unusual spending patterns by environment or application

### AWS Trusted Advisor
- Use cost optimization recommendations
- Filter recommendations by tagged resources

### Third-Party Tools
- Export cost data to business intelligence tools
- Use tags for chargeback and showback reporting

## Next Steps

1. **Activate Your Tags**: Follow the step-by-step process above
2. **Wait for Data**: Allow 2-3 days for complete data availability  
3. **Create Reports**: Set up Cost Explorer views and budgets
4. **Monitor Regularly**: Establish monthly cost review process
5. **Optimize Continuously**: Use insights to refine your tagging strategy

For ongoing tag management, see the [Automation Guide](automation-guide.md) to implement automated tagging for new resources.

## References

### AWS Documentation
- [Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
- [Activating User-Defined Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html)
- [AWS Cost Explorer User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [AWS Budgets User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html)
