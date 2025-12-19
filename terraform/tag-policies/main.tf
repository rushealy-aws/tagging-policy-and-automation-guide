# AWS Organizations Tag Policy for Mandatory Tags
# This policy enforces required tags across all accounts in the organization

resource "aws_organizations_policy" "tag_policy" {
  name        = "mandatory-tags-policy"
  description = "Enforces mandatory tags: Environment, Owner, CostCenter, Application"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Environment = {
        tag_key = {
          "@@assign" = "Environment"
        }
        tag_value = {
          "@@assign" = [
            "prod",
            "dev", 
            "test",
            "qa",
            "staging"
          ]
        }
        enforced_for = {
          "@@assign" = ["all"]
        }
      }
      Owner = {
        tag_key = {
          "@@assign" = "Owner"
        }
        tag_value = {
          "@@assign" = [
            "platform-team",
            "data-team",
            "security-team",
            "finance-team",
            "dev-team"
          ]
        }
        enforced_for = {
          "@@assign" = ["all"]
        }
      }
      CostCenter = {
        tag_key = {
          "@@assign" = "CostCenter"
        }
        tag_value = {
          "@@assign" = [
            "eng-*",
            "ops-*", 
            "finance-*",
            "security-*"
          ]
        }
        enforced_for = {
          "@@assign" = ["all"]
        }
      }
      Application = {
        tag_key = {
          "@@assign" = "Application"
        }
        enforced_for = {
          "@@assign" = ["all"]
        }
      }
    }
  })

  tags = {
    Environment = "prod"
    Owner      = "platform-team"
    CostCenter = "eng-001"
    Application = "governance"
  }
}

# Attach policy to root organization
resource "aws_organizations_policy_attachment" "tag_policy_root" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = data.aws_organizations_organization.current.roots[0].id
}

# Data source to get organization information
data "aws_organizations_organization" "current" {}

# Output the policy ID for reference
output "tag_policy_id" {
  description = "ID of the created tag policy"
  value       = aws_organizations_policy.tag_policy.id
}

output "tag_policy_arn" {
  description = "ARN of the created tag policy"
  value       = aws_organizations_policy.tag_policy.arn
}
