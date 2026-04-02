# Day 14 — Terraform Import & Migrating Existing Infrastructure

## Real-Life Example 🏗️

**The Legacy Handover:**  
You join a company that has been running AWS manually for 2 years. One VPC, 8 subnets, 3 security groups, 2 RDS instances, 1 EKS cluster — all created by clicking in the console. No Terraform anywhere.

Your mission: bring all of it under Terraform management so changes go through code review, state is tracked, and the team can provision new environments from code.

**The key constraint:** You cannot destroy and recreate anything. The databases are live. The EKS cluster has 50 pods running.

`terraform import` solves this. It brings existing resources into state without touching them.

---

## Two Ways to Import

### Old Way (Terraform < 1.5) — CLI Command

```bash
# Step 1: Write the resource block manually in main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"    # must match the real VPC exactly
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Step 2: Import the existing VPC into state
terraform import aws_vpc.main vpc-0abc123456789

# Step 3: Run plan and fix any attribute mismatches
terraform plan
# Shows ~ update for any attributes that don't match reality
# Fix your resource block until plan shows "No changes"
```

---

### New Way (Terraform >= 1.5) — Import Blocks ✅ RECOMMENDED

Declarative, tracked in Git, visible in history.

```hcl
# Add to main.tf
import {
  id = "vpc-0abc123456789"   # the real AWS resource ID
  to = aws_vpc.main          # the resource block this maps to
}

# Resource block (either write it or let Terraform generate it)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  # ...
}
```

```bash
# Let Terraform generate the resource block for you
terraform plan -generate-config-out=generated.tf

# generated.tf now contains a complete resource block
# matching the real infrastructure — review and clean up

# Apply the import
terraform apply

# Verify — should show "No changes"
terraform plan

# Remove the import block (it's a one-time operation)
```

---

## Import ID Reference

Every resource type has its own import ID format. Always check the Terraform registry docs for the resource.

| Resource | Import ID | Where to Find It |
|----------|-----------|-----------------|
| `aws_vpc` | `vpc-0abc123` | Console → VPC → VPC ID |
| `aws_subnet` | `subnet-0abc123` | Console → VPC → Subnets |
| `aws_instance` | `i-0abc123456789` | Console → EC2 → Instance ID |
| `aws_s3_bucket` | `my-bucket-name` | Bucket name (not ARN) |
| `aws_iam_role` | `my-role-name` | IAM → Roles → Role name |
| `aws_db_instance` | `my-db-identifier` | RDS → DB identifier |
| `aws_security_group` | `sg-0abc123` | Console → EC2 → Security Groups |
| `aws_eks_cluster` | `my-cluster-name` | EKS → Cluster name |
| `aws_route53_record` | `ZONE_ID_hostname_TYPE` | `Z123ABC_mysite.com_A` |
| `aws_route53_zone` | `Z123ABCDEF` | Route53 → Hosted zone ID |

---

## Full Migration Workflow

```bash
# Step 1: Discover all resources via AWS CLI
aws ec2 describe-vpcs --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock}'
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0abc123"   --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}'
aws rds describe-db-instances   --query 'DBInstances[*].DBInstanceIdentifier'

# Step 2: Add import blocks for each resource
# (in main.tf — or a separate imports.tf file)

# Step 3: Generate configs
terraform plan -generate-config-out=generated.tf

# Step 4: Review and clean up generated.tf
# Remove computed attributes (id, arn, owner_id, etc.)
# Parameterise values that should come from variables

# Step 5: Move cleaned config to main.tf, delete import blocks

# Step 6: Validate
terraform plan
# Should show "No changes" — config matches reality exactly
```

---

## Common Import Errors and Fixes

```bash
# Error: Cannot import non-existent remote object
# Cause: Wrong import ID format
# Fix: Check Terraform Registry docs for the correct ID format for this resource type

# Error: Resource already managed by Terraform
# Cause: Resource is already in state under a different name
# Fix: terraform state rm aws_vpc.old_name  # then reimport under new name

# Plan shows unexpected ~ update after import
# Cause: Your resource block attributes don't exactly match reality
# Fix: Check each attribute in the plan diff and update your code to match
#      OR run: terraform apply  (if the code represents the desired state)

# Error: id attribute not set
# Cause: The resource block needs the `id` from import but it's computed
# Fix: Remove `id` from the resource block — it's computed automatically
```
