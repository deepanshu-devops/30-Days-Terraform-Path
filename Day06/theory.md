# Day 06 — Data Sources & Resource Dependencies

## 5W + 1H

### WHAT
**Data sources** (`data {}`) read existing infrastructure — they never create, modify, or delete resources. They are read-only queries to the provider API.

**Resource dependencies** determine the order Terraform creates, updates, or destroys resources.

### WHY
- Query existing infrastructure not managed by this Terraform configuration
- Read values that are determined at runtime (e.g., latest AMI ID, current account ID)
- Create dependencies between resources that don't reference each other directly

---

## Data Source Types

### AWS-native data sources
```hcl
# Current AWS caller identity
data "aws_caller_identity" "current" {}

# Specific AMI — always get the latest Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC not managed by this Terraform (shared network)
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-services-vpc"]
  }
}

# Subnets in the shared VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

# Secrets Manager secret
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

# Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = "example.com."
  private_zone = false
}

# SSM Parameter Store
data "aws_ssm_parameter" "ami_id" {
  name = "/aws/service/eks/optimized-ami/1.29/amazon-linux-2/recommended/image_id"
}
```

## Dependency Types

### Implicit (from references)
```hcl
resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id  # Terraform knows: create VPC before subnet
}
```

### Explicit (depends_on)
```hcl
# When no direct reference exists but ordering matters
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.s3.json

  depends_on = [aws_s3_bucket_public_access_block.main]
}
```

---

## Audience-Level Explanations

### 🟢 Beginner
Data sources are like looking something up in a database. You ask AWS "what is the latest Amazon Linux AMI?" and it tells you. You use that answer in your config. You didn't create the AMI — you just looked it up.

### 🔵 Intermediate
Common patterns:
- Use `data.aws_ami` instead of hardcoding AMI IDs (they change per region and over time)
- Use `data.aws_vpc` to reference shared network infrastructure
- Use `data.aws_secretsmanager_secret_version` to inject secrets at apply time

### 🟠 Advanced
**Dependency cycles:**
Terraform will error on circular dependencies. If A references B which references A, you'll get:
```
Error: Cycle: aws_security_group.a, aws_security_group.b
```
Fix: Break the cycle using separate security group rules (`aws_security_group_rule`) instead of inline rules.

### 🔴 Expert
Data source refresh happens during `terraform plan`. The provider calls `ReadDataSource()` for each `data {}` block. This means:
- Data sources have no state stored (they're always fresh)
- Data source values can change between plans if external state changes
- Use `depends_on` on data sources to ensure resources are created before data is read
