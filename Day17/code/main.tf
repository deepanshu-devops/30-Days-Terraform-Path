################################################################################
# Day 17 — IAM Least Privilege for Terraform
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

data "aws_caller_identity" "current" {}

variable "github_org"  { type = string; default = "myorg" }
variable "github_repo" { type = string; default = "infrastructure" }

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Terraform Execution Role (assumed by GitHub Actions via OIDC)
resource "aws_iam_role" "terraform_execution" {
  name = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*" }
      }
    }]
  })

  tags = { Name = "TerraformExecutionRole", ManagedBy = "Terraform" }
}

# VPC-scoped policy
resource "aws_iam_policy" "terraform_vpc" {
  name        = "TerraformVPCPolicy"
  description = "Minimum permissions for Terraform to manage VPC resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcs",
        "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute", "ec2:DescribeSubnets",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:DescribeRouteTables",
        "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateTags", "ec2:DeleteTags",
        "ec2:DescribeAvailabilityZones", "ec2:DescribeAccountAttributes"
      ]
      Resource = "*"
    }]
  })
}

# State backend access policy
resource "aws_iam_policy" "terraform_state" {
  name        = "TerraformStateAccessPolicy"
  description = "Access to Terraform state bucket and lock table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::my-org-terraform-state/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::my-org-terraform-state"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_vpc" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = aws_iam_policy.terraform_vpc.arn
}

resource "aws_iam_role_policy_attachment" "terraform_state" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = aws_iam_policy.terraform_state.arn
}

output "role_arn" { value = aws_iam_role.terraform_execution.arn }
