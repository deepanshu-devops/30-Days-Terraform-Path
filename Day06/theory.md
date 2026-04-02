# Day 06 — Data Sources & Resource Dependencies

## Real-Life Example 🏗️

**Scenario:** You join a company mid-project. The networking team already built and owns the VPC. Your job is to deploy the application layer inside it — but you didn't create the VPC and Terraform doesn't manage it.

**Without data sources:** Copy-paste the VPC ID from the console into your code. It's fine until they recreate the VPC for some reason, the ID changes, and your code silently points at nothing.

**With data sources:**
```hcl
# Always looks up the real, current VPC ID by tag — never stale
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-services-vpc"]
  }
}

resource "aws_subnet" "app" {
  vpc_id     = data.aws_vpc.shared.id    # live reference, always current
  cidr_block = "10.0.50.0/24"
}
```

---

## Data Sources vs Resources

| | `data` block | `resource` block |
|--|--|--|
| Creates infrastructure? | ❌ No — read only | ✅ Yes |
| Shows in plan? | ❌ No | ✅ Yes (+/-/~) |
| Stored in state? | ❌ No | ✅ Yes |
| Runs on every plan? | ✅ Refreshed every time | Only when attributes change |
| Can be destroyed? | ❌ No | ✅ Yes |

---

## The Most Useful Data Sources

### Identity and Account
```hcl
# "Who is running this? What account are we in?"
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
```

### AMIs — Never Hardcode AMI IDs
```hcl
# AMI IDs change when AWS updates the image, and differ per region.
# This always gets the latest Amazon Linux 2023 in whichever region you deploy.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter { name = "name";                values = ["al2023-ami-*-x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
  filter { name = "state";               values = ["available"] }
}

resource "aws_instance" "web" {
  ami = data.aws_ami.amazon_linux_2023.id    # always current, always correct region
}
```

### Availability Zones — Never Hardcode AZ Names
```hcl
# az names differ per account (us-east-1e might not be available in your account)
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count             = 3
  availability_zone = data.aws_availability_zones.available.names[count.index]
}
```

### Existing Infrastructure You Don't Own
```hcl
# Read a VPC created by another team
data "aws_vpc" "shared" {
  filter { name = "tag:Team"; values = ["networking"] }
}

# Read subnets inside that VPC
data "aws_subnets" "private" {
  filter { name = "vpc-id";    values = [data.aws_vpc.shared.id] }
  filter { name = "tag:Tier";  values = ["private"] }
}

# Read a secret stored by the security team
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}
```

### IAM Policy Documents — No Raw JSON
```hcl
# Build an IAM policy in HCL instead of embedding a JSON string
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
```

---

## Resource Dependencies

Terraform automatically works out the creation order from references.

### Implicit Dependency (most common)
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id    # Terraform sees this reference
  cidr_block = "10.0.1.0/24"     # → creates VPC BEFORE subnet, always
}
```

### Explicit Dependency (when there's no direct reference)
```hcl
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.bucket.json

  # S3 public access block must be applied BEFORE the bucket policy
  # There's no direct reference, so we make the dependency explicit
  depends_on = [aws_s3_bucket_public_access_block.main]
}
```

### Visualise the Dependency Graph
```bash
# Requires Graphviz: brew install graphviz
terraform graph | dot -Tsvg > dependency-graph.svg
open dependency-graph.svg
```

The graph shows every arrow — which resource depends on which. Extremely useful for debugging "why is Terraform creating things in the wrong order?"

---

## Never Hardcode These Values — Always Use Data Sources

| Hardcoded (fragile) | Data Source (robust) |
|--------------------|---------------------|
| `ami = "ami-0c55b159cbfafe1f0"` | `data.aws_ami.latest.id` |
| `availability_zone = "us-east-1a"` | `data.aws_availability_zones.available.names[0]` |
| `vpc_id = "vpc-0abc123456"` | `data.aws_vpc.shared.id` |
| `account_id = "123456789012"` | `data.aws_caller_identity.current.account_id` |
| `password = "secret123"` | `data.aws_secretsmanager_secret_version.db.secret_string` |
