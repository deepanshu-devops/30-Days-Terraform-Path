# Day 21 — Managing Multi-Account AWS with Terraform

## WHAT
Production-grade AWS setups use multiple accounts for isolation:
- Management account (billing, org-level controls)
- Security account (logging, audit, GuardDuty)
- Shared services account (networking, CI/CD)
- Dev account
- Staging account
- Production account(s)

## AWS Organizations + Terraform

```hcl
provider "aws" {
  alias  = "management"
  region = "us-east-1"
  # Uses management account credentials
}

provider "aws" {
  alias  = "dev"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::DEV_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "prod"
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::PROD_ACCOUNT_ID:role/OrganizationAccountAccessRole"
    session_name = "terraform-prod-apply"
    external_id  = var.external_id  # Extra security for cross-account
  }
}
```

## Account Factory Pattern

```hcl
# Creates new AWS accounts via Organizations
resource "aws_organizations_account" "dev" {
  name      = "myorg-dev"
  email     = "aws-dev@mycompany.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.workloads.id

  lifecycle {
    # Closing an account is a 90-day process — prevent accidental deletion
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "prod" {
  name      = "myorg-prod"
  email     = "aws-prod@mycompany.com"
  role_name = "OrganizationAccountAccessRole"
  parent_id = aws_organizations_organizational_unit.workloads.id

  lifecycle { prevent_destroy = true }
}
```

## Service Control Policies (SCPs)

```hcl
resource "aws_organizations_policy" "deny_root_actions" {
  name        = "DenyRootActions"
  description = "Prevent root account actions across all member accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Action    = ["*"]
      Resource  = ["*"]
      Condition = {
        StringLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" }
      }
    }]
  })
}

resource "aws_organizations_policy" "deny_regions" {
  name = "DenyUnapprovedRegions"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyAllOutsideApprovedRegions"
      Effect    = "Deny"
      NotAction = ["iam:*", "sts:*", "support:*"]
      Resource  = ["*"]
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = ["us-east-1", "eu-west-1"] }
      }
    }]
  })
}
```

## Cross-Account State References

```hcl
# Prod account reads shared networking state
data "terraform_remote_state" "shared_network" {
  backend = "s3"
  config = {
    bucket   = "org-terraform-state-shared"
    key      = "shared/network/terraform.tfstate"
    region   = "us-east-1"
    role_arn = "arn:aws:iam::SHARED_ACCOUNT:role/StateReadOnlyRole"
  }
}
```

---

## Audience Levels

### 🟢 Beginner
Multi-account = blast radius reduction. If someone compromises dev, they can't touch prod. Keep it simple: start with 2-3 accounts (management, dev, prod).

### 🔵 Intermediate
Use `assume_role` in provider configurations to access member accounts from one Terraform config. Use AWS SSO (IAM Identity Center) for human access instead of IAM users in each account.

### 🟠 Advanced
AWS Control Tower automates account vending. Terraform can manage the OUs, SCPs, and baseline resources post-vending. Use Terragrunt for DRY multi-account configurations.

### 🔴 Expert
Build an Account Vending Machine: a Terraform + Lambda pipeline that creates new accounts, applies baseline SCPs, enables GuardDuty, enables Security Hub, creates the Terraform execution role, and sends a welcome email — all automated.
