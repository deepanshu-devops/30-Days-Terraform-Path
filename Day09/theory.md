# Day 09 — State Corruption: Causes & Prevention

## WHAT
State corruption occurs when the `.tfstate` file contains incorrect, conflicting, or truncated data that no longer accurately reflects real infrastructure.

## Causes of State Corruption

### 1. Concurrent Apply (Most Common)
Two engineers run `terraform apply` simultaneously without locking. Both read the same state version, both write back — one overwrites the other.

### 2. Interrupted Apply
Ctrl+C during apply, network failure, or CI/CD timeout mid-apply. Partial changes written, state may not reflect reality.

### 3. Manual State Editing
Editing `.tfstate` JSON directly. Even a trailing comma breaks JSON parsing.

### 4. Provider Bugs
A provider version bug causes incorrect attribute values to be written to state.

### 5. Migration Errors
Incorrectly migrating state between backends or renaming resources without using `terraform state mv`.

---

## Signs of State Corruption

```bash
# These symptoms indicate potential corruption:

# 1. Resources shown as needing recreation that clearly exist
terraform plan
# - destroy aws_rds_cluster.main
# + create  aws_rds_cluster.main
# (RDS cluster is running and healthy)

# 2. Error acquiring state lock (stuck lock from a crash)
terraform plan
# Error: Error acquiring the state lock
# Lock Info:
#   ID:        deadlocked-uuid
#   Operation: OperationTypeApply
#   Created:   2024-01-01T12:00:00Z

# 3. Error parsing state
terraform plan
# Error: Failed to load state: JSON parsing error
```

---

## Prevention Checklist

```hcl
# 1. Remote state with locking — Day 08
terraform {
  backend "s3" {
    bucket         = "my-state-bucket"
    key            = "prod/terraform.tfstate"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    region         = "us-east-1"
  }
}
```

```bash
# 2. Enable S3 versioning on state bucket
aws s3api put-bucket-versioning   --bucket my-state-bucket   --versioning-configuration Status=Enabled

# 3. Never manually edit state — use commands
terraform state mv  # rename
terraform state rm  # remove
terraform import    # bring existing into state

# 4. Backup before risky operations
aws s3 cp s3://my-state-bucket/prod/terraform.tfstate ./backup-$(date +%Y%m%d).tfstate

# 5. Lock before cross-team operations
terraform force-unlock LOCK_ID  # Only after confirming no apply is running
```

---

## Recovery Procedures

### Scenario 1: Stuck lock
```bash
terraform force-unlock <LOCK_ID>
# Only use if you're 100% sure no apply is running
```

### Scenario 2: Resources shown as needing recreation
```bash
# Import the existing resources back
terraform import aws_db_instance.main my-rds-instance-identifier
terraform import aws_vpc.main vpc-0abc12345
```

### Scenario 3: State has extra resources not in config
```bash
# Remove from state (does not delete real infrastructure)
terraform state rm aws_instance.orphan
```

### Scenario 4: Full state corruption — restore from S3 version
```bash
# List versions
aws s3api list-object-versions   --bucket my-state-bucket   --prefix prod/terraform.tfstate   --query "Versions[*].{VersionId:VersionId,LastModified:LastModified}"

# Restore specific version
aws s3api get-object   --bucket my-state-bucket   --key prod/terraform.tfstate   --version-id <VERSION_ID>   ./restored.tfstate

aws s3 cp ./restored.tfstate s3://my-state-bucket/prod/terraform.tfstate
```

---

## Audience Levels

### 🟢 Beginner
Think of state corruption like a corrupted save file in a video game. The game doesn't know what level you're on. Prevention: save often (S3 versioning), lock your save file (DynamoDB).

### 🔵 Intermediate
Always use `terraform state` commands, never hand-edit JSON. Use S3 versioning + DynamoDB. Run `terraform plan -refresh=false` to see if state parsing itself works.

### 🟠 Advanced
Build a runbook for your team covering: stuck lock procedure, how to restore from S3 version, who to notify. Make it a wiki page, not tribal knowledge.

### 🔴 Expert
For zero-downtime state recovery, use `terraform plan -target=resource.name` to isolate and fix individual corrupted resources without touching the whole state. For large states, use `terraform state pull > state.json` and `terraform state push state.json` to manipulate state programmatically.
