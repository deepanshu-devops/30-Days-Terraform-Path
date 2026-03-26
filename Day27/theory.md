# Day 27 — Top 5 Terraform Mistakes & How to Fix Them

## Mistake 1: Local State in Production
**What happened:** Stored state on a laptop. Laptop crashed during deployment. 2 days reconstructing state.
**Fix:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```
**Rule:** Remote state + DynamoDB lock. Day one. Every project. Non-negotiable.

## Mistake 2: No State Locking
**What happened:** Two engineers ran `apply` simultaneously. State corrupted. 4-hour incident.
**Fix:** DynamoDB locking (see above). AWS locks the state file while apply runs.

## Mistake 3: Hardcoded Secrets in tfvars
**What happened:** DB password in `terraform.tfvars`. Committed to Git. In history for 6 months.
**Fix:**
```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database/password"
}
# Never: password = "mypassword123"
```
**Rule:** Secrets live in Secrets Manager or Vault. Never in code. Never in `.tfvars`. Git history never forgets.

## Mistake 4: No Module Versioning
**What happened:** Shared module without version pins. Colleague "improved" it. Three environments broke simultaneously.
**Fix:**
```hcl
module "vpc" {
  source = "git::https://github.com/org/modules.git//vpc?ref=v1.2.0"
  # NEVER: source = "git::...//vpc?ref=main"
}
```
**Rule:** Always pin module versions. Treat modules like APIs. Breaking changes = major version bump.

## Mistake 5: Skipping terraform plan
**What happened:** Ran `apply` directly on a Friday afternoon. A resource was destroyed. Evening restoring from backup.
**Fix:**
```bash
terraform plan -out=tfplan   # Save plan
terraform show tfplan         # Review it
terraform apply tfplan        # Apply exact reviewed plan
```
**Rule:** Plan. Always. In CI/CD, post the plan as a PR comment. Never apply without review.

---

## Bonus Mistakes

### Mistake 6: Using count instead of for_each
Removing the first item from a `count` list destroys and recreates all subsequent resources.
Fix: Use `for_each` with maps.

### Mistake 7: Not enabling delete protection
```hcl
resource "aws_db_instance" "main" {
  deletion_protection = true   # Must be removed before destroy
}
```

### Mistake 8: Provider credentials in code
```hcl
# NEVER:
provider "aws" {
  access_key = "AKIA..."
  secret_key = "..."
}
# USE: IAM roles, OIDC, or environment variables
```

---

## Audience Levels

### 🟢 Beginner
Every mistake on this list is preventable with 10 minutes of setup. Do the setup. It will save you days.

### 🔵 Intermediate
Run a team retrospective on your current Terraform setup against this list. Score each item 1-5. Build a 30-day remediation plan.

### 🟠 Advanced
Add automated enforcement: checkov catches hardcoded values, CI enforces plan before apply, Sentinel/OPA enforces no public resources.

### 🔴 Expert
The common thread: all these mistakes come from prioritizing speed over discipline. The fix is not more tools — it's culture. Make the right way the easy way. Automate the guardrails.
