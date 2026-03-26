# Day 18 — Policy as Code: Sentinel & OPA

## WHAT
Policy as code enforces infrastructure governance rules automatically, blocking non-compliant resources before they are created.

## Why Policy as Code?
- Manual code review misses security misconfigurations at scale
- Compliance rules (encryption, tagging, no public exposure) must be enforced consistently
- Shift-left security: catch violations at plan time, not in production

---

## Option 1: HashiCorp Sentinel (Terraform Cloud/Enterprise)

Sentinel runs as a "soft mandatory" or "hard mandatory" gate between `plan` and `apply`.

```python
# policies/enforce-encryption.sentinel
import "tfplan/v2" as tfplan

# Find all S3 bucket resources
s3_buckets = filter tfplan.resource_changes as _, changes {
  changes.type is "aws_s3_bucket" and
  changes.change.actions contains "create"
}

# Check each bucket has encryption
main = rule {
  all s3_buckets as _, bucket {
    bucket.change.after.server_side_encryption_configuration is not null
  }
}
```

```hcl
# sentinel.hcl — policy set configuration
policy "enforce-encryption" {
  source            = "./policies/enforce-encryption.sentinel"
  enforcement_level = "hard-mandatory"  # or "soft-mandatory" (override allowed)
}
```

## Option 2: OPA with Conftest (Open Source)

OPA uses Rego policy language. Works with any Terraform plan.

```rego
# policies/s3-encryption.rego
package main

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  resource.change.actions[_] == "create"
  not resource.change.after.server_side_encryption_configuration
  msg := sprintf("S3 bucket '%v' must have server-side encryption enabled", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  not resource.change.after.tags.Environment
  msg := sprintf("Resource '%v' must have an 'Environment' tag", [resource.address])
}
```

```bash
# In CI/CD pipeline:
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
conftest test tfplan.json --policy policies/
```

## Common Policy Rules

| Rule | Resource | Check |
|---|---|---|
| No unencrypted S3 | aws_s3_bucket | server_side_encryption_configuration != null |
| No public RDS | aws_db_instance | publicly_accessible == false |
| No open SSH | aws_security_group | No ingress 22 from 0.0.0.0/0 |
| Required tags | all resources | tags contains Environment, Owner, Project |
| KMS encryption on RDS | aws_db_instance | storage_encrypted == true |
| Deletion protection on RDS | aws_db_instance | deletion_protection == true |

---

## Audience Levels

### 🟢 Beginner
Policy as code = automated compliance checks. Instead of hoping reviewers catch "this S3 bucket isn't encrypted", a policy blocks it before it can be applied.

### 🔵 Intermediate
Start with `conftest` + OPA — it's free, open source, and integrates with any CI/CD. Write 5 policies for your most common violations. Run on every PR.

### 🟠 Advanced
Build a policy library shared across all teams. Policies are code — version them, test them, review them. Tag policies with compliance framework IDs (SOC2 CC6.1, ISO 27001 A.13.1.1).

### 🔴 Expert
Use Sentinel's import system to check not just the plan but also actual state and external data sources. Build exception workflows: a policy fails but includes an override path with audit trail (GitHub issue approval).
