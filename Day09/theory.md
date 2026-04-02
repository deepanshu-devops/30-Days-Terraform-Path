# Day 09 — State Corruption: Causes & Prevention

## Real-Life Example 🏗️

**Monday morning. Production deployment.** Two engineers run `terraform apply` at the same time (state locking was not yet configured on this project).

Both read the same state version. Both start making changes. Engineer A finishes and writes new state. Engineer B finishes seconds later and overwrites Engineer A's state with a version that doesn't include A's changes.

Result: Terraform's state says resources exist that don't, and doesn't know about resources that do.

Running `terraform plan` now shows:
- Destroy the live RDS instance (Terraform thinks it shouldn't exist)
- Create a new RDS instance (Terraform thinks the old one is gone)

If anyone had run `apply` without checking: the production database would have been destroyed.

**Recovery: 4 hours. Prevention: DynamoDB locking + S3 versioning. Setup time: 10 minutes.**

---

## What Causes State Corruption

| Cause | How It Happens | Prevention |
|-------|---------------|-----------|
| Concurrent apply | Two people apply simultaneously | DynamoDB locking |
| Interrupted apply | Ctrl+C or network failure mid-apply | DynamoDB locking (partial lock remains) |
| Manual JSON editing | Someone edits `.tfstate` directly | Use `terraform state` commands instead |
| Provider bug | Buggy version writes wrong attributes | Pin provider versions |
| Wrong migration | Moving state between backends incorrectly | Use `terraform init -migrate-state` |
| Deleted state file | State file lost or accidentally deleted | S3 versioning, `prevent_destroy` on bucket |

---

## How to Detect Corruption

```bash
# Sign 1: Plan shows destroying healthy resources
terraform plan
# - destroy aws_rds_cluster.main   ← RDS is running fine!
# + create  aws_rds_cluster.main

# Sign 2: Duplicate entries in state
terraform state list
# aws_vpc.main
# aws_vpc.main   ← two entries for the same resource = corrupted

# Sign 3: JSON parse failure
terraform plan
# Error: Failed to load state: At 2:1: unexpected character

# Sign 4: Stuck lock from a previous crash
terraform plan
# Error: Error acquiring the state lock
# Lock Info:
#   ID:      abc-123-def
#   Created: 2024-01-15 09:32:00 UTC
```

---

## Prevention Checklist

```hcl
# ✅ 1. Remote state with DynamoDB locking (Day 08)
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# ✅ 2. S3 versioning (roll back to previous good state)
resource "aws_s3_bucket_versioning" "state" {
  versioning_configuration { status = "Enabled" }
}

# ✅ 3. Prevent accidental destroy on critical resources
resource "aws_db_instance" "prod" {
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket" "terraform_state" {
  lifecycle { prevent_destroy = true }
}

# ✅ 4. Never manually edit state — use these commands:
# terraform state mv    (rename resource)
# terraform state rm    (remove from tracking — real infra stays)
# terraform import      (bring existing infra in)
```

---

## Recovery Procedures

### Scenario 1: Stuck Lock (Terraform crashed mid-apply)
```bash
# Always check: is anyone actually running apply right now?
aws dynamodb get-item   --table-name terraform-state-lock   --key '{"LockID": {"S": "bucket/path/terraform.tfstate"}}'
# Read the "Who" and "Created" fields

# Only unlock if you're certain no apply is running:
terraform force-unlock <LOCK-ID>
```

### Scenario 2: Resources Shown Needing Recreation (shouldn't exist)
```bash
# Import the existing resources back into state
terraform import aws_vpc.main vpc-0abc123456
terraform import aws_db_instance.main my-rds-identifier
terraform import aws_eks_cluster.main my-cluster-name

# Verify — plan should show "No changes"
terraform plan
```

### Scenario 3: Restore from S3 Version
```bash
# List available state versions
aws s3api list-object-versions   --bucket my-org-terraform-state   --prefix prod/vpc/terraform.tfstate   --query "Versions[*].{VersionId:VersionId,LastModified:LastModified}"

# Restore the last known-good version
aws s3api copy-object   --bucket my-org-terraform-state   --copy-source my-org-terraform-state/prod/vpc/terraform.tfstate?versionId=<VERSION_ID>   --key prod/vpc/terraform.tfstate

# Verify
terraform plan    # should now show correct state
```

### Scenario 4: Orphaned Resources (in state but not in config)
```bash
# Remove from state — real infrastructure is untouched
terraform state rm aws_instance.old_orphan
terraform state rm module.legacy.aws_vpc.old
```

---

## Safe State Operations Reference

```bash
terraform state list                           # list all tracked resources
terraform state show aws_vpc.main              # full details for one resource
terraform state mv aws_vpc.old aws_vpc.main    # rename without destroy/recreate
terraform state rm aws_s3_bucket.temp          # remove tracking (infra stays)
terraform state pull > backup-$(date +%Y%m%d).tfstate  # download state locally
terraform import aws_vpc.main vpc-0abc123      # bring existing infra into state
terraform refresh                              # sync state with real infra (careful!)
```
