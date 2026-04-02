# Day 18 — Policy as Code: Sentinel & OPA

## Real-Life Example 🏗️

**The Compliance Failure:**  
Your company's security policy: "No S3 bucket may store data without encryption. No RDS instance may be publicly accessible."

Three teams are deploying independently. Code review happens but reviewers are humans — they miss things under pressure. Two months later, a security audit finds:
- 3 unencrypted S3 buckets in staging
- 1 publicly accessible RDS instance in prod (created during an incident fix)

**With policy as code:**  
Every PR is scanned by OPA before merge. Every `terraform apply` in CI/CD is blocked if any policy fails. The audit finds zero violations.

---

## What is Policy as Code?

Policy as code is automating the enforcement of infrastructure rules. Instead of hoping reviewers catch violations, you codify the rules and let automation enforce them.

```
terraform plan → generates plan JSON → OPA/Sentinel checks policies → PASS or FAIL
                                                                              │
                                                                              └── FAIL = PR is blocked
                                                                                  apply cannot run
```

---

## Option 1: OPA with Conftest (Open Source — Recommended to Start)

### Writing a Policy in Rego
```rego
# policies/s3-security.rego
package main

# Deny any S3 bucket without encryption
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  resource.change.actions[_] == "create"
  not resource.change.after.server_side_encryption_configuration
  msg := sprintf(
    "FAIL: S3 bucket '%v' must have server-side encryption configured",
    [resource.address]
  )
}

# Deny any RDS that is publicly accessible
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_db_instance"
  resource.change.after.publicly_accessible == true
  msg := sprintf(
    "FAIL: RDS instance '%v' must not be publicly accessible",
    [resource.address]
  )
}

# Deny any resource missing required tags
deny[msg] {
  resource := input.resource_changes[_]
  resource.change.actions[_] == "create"
  required_tags := {"Environment", "Owner", "Project"}
  missing := required_tags - {t | resource.change.after.tags[t]}
  count(missing) > 0
  msg := sprintf(
    "FAIL: '%v' is missing required tags: %v",
    [resource.address, missing]
  )
}
```

### Running in CI/CD
```bash
# Generate the plan JSON
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Run policies
conftest test tfplan.json --policy policies/

# Output on failure:
# FAIL - tfplan.json - main - FAIL: S3 bucket 'aws_s3_bucket.logs' must have server-side encryption configured
# FAIL - tfplan.json - main - FAIL: RDS instance 'aws_db_instance.main' must not be publicly accessible

# Output on success:
# 2 tests, 2 passed, 0 warnings, 0 failures
```

### GitHub Actions Integration
```yaml
- name: OPA Policy Check
  run: |
    terraform plan -out=tfplan.binary
    terraform show -json tfplan.binary > tfplan.json
    conftest test tfplan.json --policy policies/
```

---

## Option 2: HashiCorp Sentinel (Terraform Cloud/Enterprise)

Sentinel runs between `plan` and `apply`. Hard mandatory policies cannot be overridden.

```python
# sentinel/enforce-encryption.sentinel
import "tfplan/v2" as tfplan

# All S3 buckets must have encryption configured
s3_encryption = rule {
  all tfplan.resource_changes as _, changes {
    changes.type is not "aws_s3_bucket" or
    changes.change.after.server_side_encryption_configuration is not null
  }
}

main = rule { s3_encryption }
```

```hcl
# sentinel.hcl
policy "enforce-encryption" {
  source            = "./sentinel/enforce-encryption.sentinel"
  enforcement_level = "hard-mandatory"    # cannot be overridden, period
}
```

---

## Policy Library: Rules We Enforce

| Policy | Blocks | Reason |
|--------|--------|--------|
| `no-public-rds` | `publicly_accessible = true` | Data exposure |
| `require-s3-encryption` | S3 without SSE | Data at rest compliance |
| `require-s3-versioning` | S3 without versioning | Data recovery |
| `require-tags` | Missing Environment/Owner/Project | Cost attribution + ownership |
| `no-open-ssh` | Port 22 open to 0.0.0.0/0 | Attack surface |
| `require-deletion-protection` | RDS without `deletion_protection` | Accidental data loss |
| `no-public-s3` | S3 with public access | Data exposure |
| `require-kms-encryption` | Resources not using KMS | Compliance |
