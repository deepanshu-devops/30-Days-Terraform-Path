# Day 08 — Remote State: S3 + DynamoDB Locking

## Real-Life Example 🏗️

**Friday, 3:15 PM.** Two engineers on your team both need to apply Terraform changes before the weekend. They coordinate via Slack but there's a 5-minute gap.

- Engineer A: reads state → starts apply → gets halfway through
- Engineer B: also reads state (same version) → starts apply simultaneously
- Both write their new state back → one overwrites the other
- Result: state file shows EC2 instances that don't exist, misses ones that do
- Monday morning: `terraform plan` shows destroying your entire prod cluster

**This happened at Amdocs.** Four hours of incident response. The fix: DynamoDB locking. Ten minutes to set up. Zero incidents since.

---

## Why Local State Fails in Teams

```
LOCAL STATE (bad for teams)                REMOTE STATE (correct)
─────────────────────────────              ──────────────────────────
📁 terraform.tfstate                       ☁️  S3 bucket
   Lives on YOUR laptop                       Accessible by entire team
   Not backed up                              Versioned (S3 versioning)
   If laptop dies → state gone                Encrypted at rest (KMS)
   Two people can apply → corruption          Locked during apply (DynamoDB)
   CI/CD can't access it                      CI/CD works from anywhere
```

---

## The S3 Backend Configuration

```hcl
# provider.tf — root modules only, never in reusable modules
terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "my-org-terraform-state"   # S3 bucket name
    key            = "prod/vpc/terraform.tfstate" # unique path per project
    region         = "us-east-1"                  # bucket region
    dynamodb_table = "terraform-state-lock"        # locking table
    encrypt        = true                          # encrypt state at rest
  }
}
```

**State key naming convention (use this):**
```
{account-id}/{region}/{environment}/{service}/terraform.tfstate

Examples:
  123456789012/us-east-1/prod/vpc/terraform.tfstate
  123456789012/us-east-1/prod/eks/terraform.tfstate
  123456789012/us-east-1/prod/rds/terraform.tfstate
  123456789012/us-east-1/staging/vpc/terraform.tfstate
```

---

## How DynamoDB Locking Works

```
terraform apply starts
       │
       ▼
Write LockID to DynamoDB:
  {"LockID": "my-bucket/prod/vpc/terraform.tfstate",
   "Info": {"Operation":"Apply","Who":"alice@laptop","Created":"..."}}
       │
       ├── If item already exists → ERROR: state is locked by alice@laptop
       │   (second apply fails safely — no corruption)
       │
       ▼
Make infrastructure changes
       │
       ▼
Write new terraform.tfstate to S3
       │
       ▼
Delete DynamoDB lock item (unlock)
```

---

## Bootstrap: Create the Backend (Run Once)

The state bucket and lock table can't use the backend they create (chicken-and-egg). Bootstrap with local state:

```bash
cd Day08/code
terraform init      # uses LOCAL state for this bootstrap only
terraform apply

# Copy the backend_config_snippet output
# → paste it into provider.tf of all your other projects
```

---

## Migrating Existing Projects to Remote State

```bash
# 1. Add the backend block to your project's provider.tf
# 2. Run:
terraform init -migrate-state
# "Would you like to copy existing state to the new backend?" → yes

# 3. Verify
aws s3 ls s3://my-org-terraform-state/prod/vpc/
terraform state list    # should show your resources
```

---

## Cross-Stack State References

The real power: one Terraform configuration can read outputs from another.

```hcl
# In the EKS project — reads networking from the VPC project
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config  = {
    bucket = "my-org-terraform-state"
    key    = "prod/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

module "eks" {
  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```

VPC changes → VPC team applies → EKS reads the new outputs automatically on next apply.

---

## Emergency: Stuck Lock

If Terraform crashes mid-apply, the lock stays in DynamoDB.

```bash
# First: verify no apply is actually running
aws dynamodb get-item   --table-name terraform-state-lock   --key '{"LockID": {"S": "my-bucket/prod/vpc/terraform.tfstate"}}'

# Read the "Info" field — contains who locked it and when
# Only force-unlock if you are CERTAIN nothing is running

terraform force-unlock <LOCK-ID-FROM-THE-ERROR-MESSAGE>
```

---

## S3 Bucket Security Requirements

```hcl
# All four of these must be applied to your state bucket:

# 1. Versioning — rollback to previous state if corruption occurs
resource "aws_s3_bucket_versioning" "state" {
  versioning_configuration { status = "Enabled" }
}

# 2. Encryption — state can contain passwords, private keys
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}

# 3. Block public access — state files must never be public
resource "aws_s3_bucket_public_access_block" "state" {
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}

# 4. Prevent accidental deletion of the bucket itself
resource "aws_s3_bucket" "state" {
  lifecycle { prevent_destroy = true }
}
```
