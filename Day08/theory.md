# Day 08 — Remote State with S3 + DynamoDB Locking

## 5W + 1H

### WHO
Any team (2+ engineers) using Terraform together. Remote state is mandatory for teams.

### WHAT
Remote state stores the `terraform.tfstate` file in a shared, versioned location instead of a local file.

**S3 backend configuration:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"        # S3 bucket name
    key            = "prod/vpc/terraform.tfstate" # Path within bucket
    region         = "us-east-1"                 # Bucket region
    dynamodb_table = "terraform-state-lock"      # Locking table name
    encrypt        = true                         # Encrypt state at rest
    
    # Optional but recommended:
    versioning     = true  # Enable bucket versioning (set on bucket resource)
    kms_key_id     = "arn:aws:kms:us-east-1:..."  # Custom KMS key
  }
}
```

### WHY
- **Shared access:** Any team member (or CI/CD) can run Terraform
- **Locking:** Prevents concurrent applies from corrupting state
- **Versioning:** Roll back to previous state on corruption
- **Security:** Access controlled via IAM, encrypted at rest

### HOW

**Step 1: Create the S3 bucket and DynamoDB table (bootstrap)**
```hcl
# bootstrap/main.tf — run once manually
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-org-terraform-state"
  
  lifecycle {
    prevent_destroy = true  # Never accidentally delete this
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"  # KMS for better security than AES256
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  point_in_time_recovery { enabled = true }
  
  lifecycle {
    prevent_destroy = true
  }
}
```

**Step 2: Reference the backend in your project**
```hcl
# projects/vpc/main.tf
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "projects/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## State Backend Key Strategy

Use a consistent key naming scheme:
```
{account}/{region}/{environment}/{service}/terraform.tfstate

Examples:
  123456789/us-east-1/prod/vpc/terraform.tfstate
  123456789/us-east-1/prod/eks/terraform.tfstate
  123456789/us-east-1/prod/rds/terraform.tfstate
```

---

## Audience-Level Explanations

### 🟢 Beginner
Local state = your notebook on your desk. Remote state = a shared Google Doc the whole team can access. If your notebook burns, the infrastructure is lost. If the Google Doc is gone, you have backups.

### 🔵 Intermediate
```bash
# Migrating from local to S3 backend:
# 1. Add backend block to terraform {}
# 2. Run:
terraform init -migrate-state
# Terraform will ask: "Do you want to copy existing state to the new backend?"
# Type: yes
```

### 🟠 Advanced
**Cross-stack state references:**
```hcl
# In the VPC stack, output VPC and subnet IDs
output "vpc_id"            { value = aws_vpc.main.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

# In the EKS stack, read VPC outputs
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "my-org-terraform-state"
    key    = "projects/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

module "eks" {
  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```

### 🔴 Expert
**State lock implementation:**
DynamoDB lock item has this structure:
```json
{
  "LockID": "my-bucket/path/terraform.tfstate",
  "Info": "{"ID":"uuid","Operation":"OperationTypeApply","Who":"user@host","Version":"1.6.0","Created":"2024-01-01T00:00:00Z"}",
  "Path": "my-bucket/path/terraform.tfstate"
}
```

If Terraform crashes, the lock may be stuck. Force-unlock with:
```bash
terraform force-unlock LOCK_ID
```

**State access IAM policy (least privilege):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::my-org-terraform-state/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::my-org-terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/terraform-state-lock"
    }
  ]
}
```
