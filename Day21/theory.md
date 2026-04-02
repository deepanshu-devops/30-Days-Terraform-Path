# Day 21 — Managing Multi-Account AWS with Terraform

## Real-Life Example 🏗️

**The Single-Account Blast Radius Problem:**  
Everything in one AWS account: dev, staging, prod, CI/CD tools, log buckets.

A new engineer is working on dev and runs `terraform destroy` to clean up their test resources. They're in the right directory but the wrong workspace. Prod state is selected. The destroy removes prod resources.

Even with `prevent_destroy`, the blast radius — the scope of what can be accidentally affected — is huge when everything shares one account.

**With multi-account:**  
Dev, staging, and prod are completely separate AWS accounts with separate credentials and separate Terraform states. An error in the dev account cannot affect prod. Period.

---

## AWS Multi-Account Architecture

```
Root Management Account
└── AWS Organizations
    ├── Security OU
    │   └── Security Account
    │       (CloudTrail, GuardDuty, Security Hub for all accounts)
    ├── Infrastructure OU
    │   └── Shared Services Account
    │       (networking, container registry, CI/CD tools)
    └── Workloads OU
        ├── Dev Account         (wide permissions, low risk)
        ├── Staging Account     (production-like, controlled)
        └── Prod Account        (narrow permissions, MFA, alerts on every change)
```

---

## Multi-Provider for Multi-Account in Terraform

```hcl
# provider.tf — one provider alias per account
provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-dev-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  }
}

provider "aws" {
  alias  = "staging"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.staging_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-staging"
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-prod"
    # extra security: require MFA for prod role assumption
    # external_id = var.prod_external_id
  }
}
```

```hcl
# main.tf — resources go to specific accounts
resource "aws_vpc" "dev" {
  provider   = aws.dev
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "dev-vpc" }
}

resource "aws_vpc" "prod" {
  provider   = aws.prod
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "prod-vpc" }
}
```

---

## Service Control Policies — Org-Level Guardrails

```hcl
# Prevent root account actions across all member accounts
resource "aws_organizations_policy" "deny_root" {
  name = "DenyRootActions"
  type = "SERVICE_CONTROL_POLICY"

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

# Restrict all accounts to approved regions only
resource "aws_organizations_policy" "approved_regions" {
  name = "ApprovedRegionsOnly"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Statement = [{
      Effect    = "Deny"
      NotAction = ["iam:*", "sts:*", "support:*"]
      Resource  = ["*"]
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = ["us-east-1", "eu-west-1"]
        }
      }
    }]
  })
}
```

---

## Cross-Account State References

```hcl
# Prod EKS reads networking outputs from Shared Services account
data "terraform_remote_state" "shared_network" {
  backend = "s3"
  config  = {
    bucket   = "shared-services-terraform-state"
    key      = "networking/terraform.tfstate"
    region   = "us-east-1"
    role_arn = "arn:aws:iam::SHARED_SERVICES_ACCOUNT:role/StateReadOnlyRole"
  }
}

module "eks" {
  vpc_id     = data.terraform_remote_state.shared_network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.shared_network.outputs.private_subnet_ids
}
```
