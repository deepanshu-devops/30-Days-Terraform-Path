################################################################################
# Day 21 — Multi-Account AWS Organization Setup
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# Management account provider
provider "aws" {
  alias  = "management"
  region = "us-east-1"
}

# Dev account — assumes cross-account role
provider "aws" {
  alias  = "dev"
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-dev"
  }
}

# Prod account — assumes cross-account role with extra controls
provider "aws" {
  alias  = "prod"
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-prod"
  }
}

variable "dev_account_id"  { type = string; default = "111111111111" }
variable "prod_account_id" { type = string; default = "222222222222" }

# Organization structure
resource "aws_organizations_organization" "main" {
  provider = aws.management
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "guardduty.amazonaws.com",
  ]
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

resource "aws_organizations_organizational_unit" "workloads" {
  provider  = aws.management
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# SCP: Deny root actions in all member accounts
resource "aws_organizations_policy" "deny_root" {
  provider    = aws.management
  name        = "DenyRootActions"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Action    = ["*"]
      Resource  = ["*"]
      Condition = { StringLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" } }
    }]
  })
}

# Resources in dev account
resource "aws_vpc" "dev" {
  provider   = aws.dev
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "dev-vpc", Account = "dev", ManagedBy = "Terraform" }
}

# Resources in prod account
resource "aws_vpc" "prod" {
  provider   = aws.prod
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "prod-vpc", Account = "prod", ManagedBy = "Terraform" }
}

output "dev_vpc_id"  { value = aws_vpc.dev.id }
output "prod_vpc_id" { value = aws_vpc.prod.id }
