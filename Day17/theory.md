# Day 17 — IAM Least Privilege with Terraform

## Real-Life Example 🏗️

**The Admin Access Incident:**  
Your Terraform CI/CD pipeline uses an IAM user with `AdministratorAccess`.  
A supply-chain attack compromises a dependency in your pipeline.  
The attacker now has full AWS admin credentials. They spin up 500 GPU instances for crypto mining over a weekend.  
Bill: $47,000.

**With least privilege:**  
The Terraform role can only create VPCs and EKS clusters. The attacker gets a role that can create a VPC. No GPU instances, no IAM users, no S3 data access. Blast radius: zero.

---

## The Three Principles

### 1. Use IAM Roles, Not IAM Users

IAM users have permanent credentials. IAM roles have temporary, auto-expiring credentials.

```hcl
# CI/CD assumes this role via OIDC — no stored access keys anywhere
resource "aws_iam_role" "terraform_ci" {
  name = "TerraformCIRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
        }
      }
    }]
  })
}
```

### 2. Scope Permissions to What Terraform Actually Needs

```hcl
resource "aws_iam_policy" "terraform_network" {
  name        = "TerraformNetworkPolicy"
  description = "Minimum permissions for managing VPC resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        # Only the specific API calls Terraform makes for VPC resources
        "ec2:CreateVpc",         "ec2:DeleteVpc",         "ec2:DescribeVpcs",
        "ec2:CreateSubnet",      "ec2:DeleteSubnet",      "ec2:DescribeSubnets",
        "ec2:CreateRouteTable",  "ec2:DeleteRouteTable",  "ec2:DescribeRouteTables",
        "ec2:CreateRoute",       "ec2:DeleteRoute",
        "ec2:AssociateRouteTable","ec2:DisassociateRouteTable",
        "ec2:CreateInternetGateway","ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway","ec2:DetachInternetGateway",
        "ec2:CreateSecurityGroup","ec2:DeleteSecurityGroup","ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress","ec2:RevokeSecurityGroupIngress",
        "ec2:CreateTags","ec2:DeleteTags","ec2:DescribeAvailabilityZones"
      ]
      Resource = "*"
    }]
  })
}
```

### 3. Separate Roles Per Environment

```
TerraformRole-Dev (dev AWS account)
  → Broad permissions (can experiment, break things)
  → Can destroy and recreate freely

TerraformRole-Staging (staging AWS account)
  → Moderate permissions
  → Destroy requires approval

TerraformRole-Prod (prod AWS account)
  → Narrow permissions (exactly what prod infra needs)
  → All actions require MFA (if using console)
  → `prevent_destroy = true` on all critical resources
```

---

## State Backend Access Policy

The Terraform role also needs access to read/write state:

```hcl
resource "aws_iam_policy" "terraform_state" {
  name = "TerraformStateAccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::my-org-terraform-state/prod/*"
        # Scoped to prod/ prefix only — can't read dev state
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = "arn:aws:s3:::my-org-terraform-state"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:us-east-1:*:table/terraform-state-lock"
      }
    ]
  })
}
```

---

## Verifying Permissions Without Applying

```bash
# Test if the role can create a VPC (should be allowed)
aws iam simulate-principal-policy   --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformCIRole   --action-names ec2:CreateVpc   --resource-arns "*"   --query "EvaluationResults[].EvalDecision"
# → "allowed"

# Test if the role can create an IAM user (should be denied)
aws iam simulate-principal-policy   --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformCIRole   --action-names iam:CreateUser   --resource-arns "*"   --query "EvaluationResults[].EvalDecision"
# → "implicitDeny"
```

---

## Permission Boundaries (Advanced)

Even if someone gives the Terraform role extra permissions, a boundary caps what it can do:

```hcl
resource "aws_iam_role" "terraform_ci" {
  permissions_boundary = aws_iam_policy.terraform_boundary.arn

  # Even if someone attaches AdministratorAccess to this role,
  # the boundary ensures it can never exceed the boundary policy
}

resource "aws_iam_policy" "terraform_boundary" {
  name = "TerraformPermissionBoundary"
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:*", "eks:*", "rds:*"]   # max allowed — nothing outside this
      Resource = "*"
    }]
  })
}
```
