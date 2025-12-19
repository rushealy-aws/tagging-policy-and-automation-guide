# AWS Tagging Strategy Worksheet

## Instructions

Use this worksheet to define your organization's specific tag values. Fill in the sections below with values that align with your business structure, operational needs, and compliance requirements.

## Mandatory Tag Values

### Environment Values

Define your SDLC stages and environments:

| Environment | Description | Example Use Case |
|-------------|-------------|------------------|
| `prod` | Production workloads | Customer-facing applications |
| `dev` | Development environment | _Fill in your description_ |
| `test` | Testing environment | _Fill in your description_ |
| `qa` | Quality assurance environment | _Fill in your description_ |
| `staging` | Pre-production staging | _Fill in your description_ |
| ____________ | _Add your environment_ | _Fill in description_ |
| ____________ | _Add your environment_ | _Fill in description_ |

**Your Environment Values:**
```
environment=_____________
environment=_____________
environment=_____________
environment=_____________
```

### Owner Values

Define your teams, departments, or business units:

| Owner | Department/Team | Contact/Lead |
|-------|-----------------|--------------|
| `platform-team` | Platform Engineering | _Fill in contact_ |
| `data-team` | Data Engineering | _Fill in contact_ |
| `security-team` | Information Security | _Fill in contact_ |
| `finance-team` | Finance Operations | _Fill in contact_ |
| ______________ | _Add your team_ | _Fill in contact_ |
| ______________ | _Add your team_ | _Fill in contact_ |
| ______________ | _Add your team_ | _Fill in contact_ |

**Your Owner Values:**
```
owner=_______________
owner=_______________
owner=_______________
owner=_______________
```

### Cost Center Values

Define your budget codes or cost centers:

| Cost Center | Department | Budget Owner |
|-------------|------------|--------------|
| `eng-001` | Engineering | _Fill in owner_ |
| `ops-002` | Operations | _Fill in owner_ |
| `finance-003` | Finance | _Fill in owner_ |
| `security-004` | Security | _Fill in owner_ |
| _____________ | _Add your cost center_ | _Fill in owner_ |
| _____________ | _Add your cost center_ | _Fill in owner_ |
| _____________ | _Add your cost center_ | _Fill in owner_ |

**Your Cost Center Values:**
```
costcenter=_______________
costcenter=_______________
costcenter=_______________
costcenter=_______________
```

### Application Values

Define your applications and workloads:

| Application | Description | Primary Team |
|-------------|-------------|--------------|
| `customer-portal` | Customer-facing web application | _Fill in team_ |
| `admin-dashboard` | Internal admin interface | _Fill in team_ |
| `data-pipeline` | ETL and data processing | _Fill in team_ |
| `api-gateway` | API management layer | _Fill in team_ |
| ________________ | _Add your application_ | _Fill in team_ |
| ________________ | _Add your application_ | _Fill in team_ |
| ________________ | _Add your application_ | _Fill in team_ |

**Your Application Values:**
```
application=_______________
application=_______________
application=_______________
application=_______________
```

## Optional Tag Values

### Operating System Values

Define your OS types for patch management:

| OS Value | Description | Patch Schedule |
|----------|-------------|----------------|
| `linux` | Generic Linux distributions | _Fill in schedule_ |
| `amazon-linux` | Amazon Linux 2 | _Fill in schedule_ |
| `ubuntu` | Ubuntu distributions | _Fill in schedule_ |
| `windows` | Windows Server | _Fill in schedule_ |
| ____________ | _Add your OS type_ | _Fill in schedule_ |

**Your OS Values:**
```
os=_______________
os=_______________
os=_______________
```

### Backup Values

Define your backup requirements:

| Backup Value | Description | Retention Period |
|--------------|-------------|------------------|
| `required` | Must be backed up | _Fill in period_ |
| `not-required` | No backup needed | N/A |
| `daily` | Daily backup schedule | _Fill in period_ |
| `weekly` | Weekly backup schedule | _Fill in period_ |
| ____________ | _Add your backup type_ | _Fill in period_ |

**Your Backup Values:**
```
backup=_______________
backup=_______________
backup=_______________
```

### Data Classification Values

Define your data sensitivity levels:

| Classification | Description | Access Requirements |
|----------------|-------------|-------------------|
| `public` | Publicly available data | _Fill in requirements_ |
| `internal` | Internal company data | _Fill in requirements_ |
| `confidential` | Sensitive business data | _Fill in requirements_ |
| `restricted` | Highly sensitive data | _Fill in requirements_ |
| _____________ | _Add your classification_ | _Fill in requirements_ |

**Your Data Classification Values:**
```
dataclassification=_______________
dataclassification=_______________
dataclassification=_______________
```

### Project Values

Define your projects or initiatives:

| Project | Description | Timeline |
|---------|-------------|----------|
| `migration-2024` | Cloud migration project | _Fill in timeline_ |
| `modernization` | Application modernization | _Fill in timeline_ |
| `compliance-sox` | SOX compliance initiative | _Fill in timeline_ |
| ________________ | _Add your project_ | _Fill in timeline_ |
| ________________ | _Add your project_ | _Fill in timeline_ |

**Your Project Values:**
```
project=_______________
project=_______________
project=_______________
```

## Custom Tags (Optional)

Add any additional tags specific to your organization:

### Custom Tag 1
- **Tag Key:** `_______________`
- **Purpose:** _Describe the purpose_
- **Values:**
  ```
  _______________=_______________
  _______________=_______________
  _______________=_______________
  ```

### Custom Tag 2
- **Tag Key:** `_______________`
- **Purpose:** _Describe the purpose_
- **Values:**
  ```
  _______________=_______________
  _______________=_______________
  _______________=_______________
  ```

### Custom Tag 3
- **Tag Key:** `_______________`
- **Purpose:** _Describe the purpose_
- **Values:**
  ```
  _______________=_______________
  _______________=_______________
  _______________=_______________
  ```

## Validation Checklist

Before implementing your tagging strategy, verify:

- [ ] All mandatory tag values are defined
- [ ] Tag values follow naming conventions (lowercase, hyphens)
- [ ] No personally identifiable information (PII) in tag values
- [ ] Cost center codes align with finance team requirements
- [ ] Team/owner values match organizational structure
- [ ] Environment values cover all SDLC stages
- [ ] Application values cover all major workloads

## Implementation Notes

Use this space to document any specific implementation considerations:

**Naming Convention Exceptions:**
_Document any exceptions to the standard naming convention_

**Integration Requirements:**
_Note any integration requirements with existing systems_

**Compliance Considerations:**
_Document any compliance-specific tagging requirements_

**Migration Strategy:**
_Notes on migrating from existing tagging schemes_

## Approval

**Strategy Reviewed By:**
- Name: _________________ Title: _________________ Date: _________
- Name: _________________ Title: _________________ Date: _________
- Name: _________________ Title: _________________ Date: _________

**Strategy Approved By:**
- Name: _________________ Title: _________________ Date: _________

---

**Next Steps:** After completing this worksheet, implement your tagging strategy using the [Implementation Guide](implementation-guide.md).
