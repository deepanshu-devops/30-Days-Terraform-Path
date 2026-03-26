# Day 17 — IAM Least Privilege with Terraform

## WHAT
Terraform needs AWS permissions to create, modify, and destroy resources. The principle of least privilege means Terraform gets only the permissions it actually needs — nothing more.

## Why Not Admin Access?
- If Terraform credentials are compromised, attacker has admin access
- Blast radius: a bug in code can accidentally delete anything
- Compliance: most frameworks (SOC2, ISO27001) require least privilege

---

## Step 1: Use IAM Roles, Not IAM Users

```hcl
# Terraform execution role — assumed by CI/CD
resource "aws_iam_role" "terraform_execution" {
  name = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow GitHub Actions OIDC to assume this role
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
          }
        }
      }
    ]
  })
}
```

## Step 2: Scope Permissions to What Terraform Manages

```hcl
resource "aws_iam_policy" "terraform_vpc" {
  name        = "TerraformVPCPolicy"
  description = "Permissions for Terraform to manage VPC resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:DescribeVpcs", "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:DescribeSubnets",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:DescribeRouteTables",
          "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_vpc" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = aws_iam_policy.terraform_vpc.arn
}
```

## Step 3: Separate Roles Per Environment

```
TerraformRole-Dev  (dev AWS account)
  - Broad permissions
  - Can destroy resources freely

TerraformRole-Staging  (staging AWS account)
  - Moderate permissions
  - Requires MFA for destroy

TerraformRole-Prod  (prod AWS account)
  - Narrow permissions (only what's needed)
  - Requires MFA + approval
  - Deny delete on critical resources
```

## Step 4: Deny Critical Destructive Actions

```hcl
resource "aws_iam_policy" "terraform_deny_dangerous" {
  name = "TerraformDenyDangerousActions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDangerousActions"
        Effect = "Deny"
        Action = [
          "ec2:DeleteVpc",           # Can't delete VPCs
          "rds:DeleteDBInstance",    # Can't delete RDS
          "dynamodb:DeleteTable",    # Can't delete DynamoDB
          "s3:DeleteBucket"          # Can't delete S3 buckets
        ]
        Resource = "*"
        Condition = {
          "BoolIfExists" = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

---

## Audience Levels

### 🟢 Beginner
Think of IAM as a keycard system. Terraform needs a keycard that opens only the rooms it needs to work in — not the master keycard that opens everything.

### 🔵 Intermediate
Start with AWS-managed policies for common services (AmazonEC2FullAccess, etc.) during development. Lock down to custom policies before production. Use IAM Access Analyzer to find unused permissions.

### 🟠 Advanced
Use permission boundaries on the Terraform role: even if the policy says Allow, the boundary caps what the role can do. Useful for restricting Terraform from creating overly-powerful IAM roles.

### 🔴 Expert
Use AWS IAM policy simulator to test your policies before applying. Build a policy generation pipeline: parse Terraform plan output → extract resource types → generate minimum required IAM policy automatically.
