# Day 14 — Terraform Import & Migrating Existing Infra

## WHAT
`terraform import` brings existing infrastructure (created manually or by another tool) into Terraform state management, without recreating it.

## When to Use Import
- Taking over manually-created infrastructure
- Migrating from CloudFormation or Pulumi to Terraform
- Recovering from state corruption
- Onboarding existing resources into IaC governance

## Import Workflow

### Old Method (Terraform < 1.5)
```bash
# 1. Write the resource block in your .tf file
# 2. Run import
terraform import aws_vpc.main vpc-0abc123456

# Problem: You had to manually write the correct config
# Plan would show drift until your config matched reality
```

### New Method: Import Blocks (Terraform >= 1.5) ✅ RECOMMENDED
```hcl
# Add import block to your config
import {
  id = "vpc-0abc123456"
  to = aws_vpc.main
}

# Run plan — Terraform shows what the resource config should look like
terraform plan

# Apply — imports the resource
terraform apply

# Generate config automatically (Terraform 1.5+)
terraform plan -generate-config-out=generated.tf
```

## Common Import IDs

| Resource | Import ID Example |
|---|---|
| `aws_vpc` | `vpc-0abc123456` |
| `aws_instance` | `i-1234567890abcdef0` |
| `aws_s3_bucket` | `my-bucket-name` |
| `aws_iam_role` | `my-role-name` |
| `aws_security_group` | `sg-0abc123456` |
| `aws_db_instance` | `my-rds-identifier` |
| `aws_route53_record` | `ZONE_ID_hostname_type` |
| `aws_eks_cluster` | `cluster-name` |

## Practical Migration Strategy

```bash
# 1. Discover existing resources
aws ec2 describe-vpcs --filters "Name=tag:managed-by,Values=manual"

# 2. Write resource blocks (or use -generate-config-out)
# 3. Import
terraform import aws_vpc.main vpc-0abc

# 4. Compare plan — fix any drift in your config
terraform plan
# Shows: ~ update (things that don't match)

# 5. Update your .tf to match reality, OR apply to bring infra to match config
# Which you choose depends on: is reality correct, or is your code correct?

# 6. Plan should show no changes
terraform plan  # "No changes"
```

## Audience Levels

### 🟢 Beginner
Import is how you "adopt" existing infrastructure into Terraform. Think of it like adding an existing house to your blueprint. The house already exists — you're just drawing it on the blueprint so Terraform can manage it.

### 🔵 Intermediate
Use `terraform plan -generate-config-out=generated.tf` to have Terraform auto-generate the resource block from the existing resource. Review and clean up the generated config before committing.

### 🟠 Advanced
For large-scale migrations (100+ resources), build a script that:
1. Lists existing resources via AWS CLI
2. Generates import blocks
3. Runs `terraform plan -generate-config-out` in batches
4. Validates each import with plan

### 🔴 Expert
`terraformer` is an open-source tool that can auto-generate Terraform code + import from existing infra. Better for bulk migrations. For ongoing governance, build a drift detection pipeline that flags resources created outside Terraform and triggers import PRs automatically.
