# Day 19 — Security Scanning: Checkov & tfsec

## Real-Life Example 🏗️

**The Misconfiguration That Made It to Production:**  
A developer creates an EC2 instance. They add a security group that opens port 22 to 0.0.0.0/0 for debugging. "I'll close it after testing." They forget.

Three months later: a security audit finds the open SSH port. No breach occurred, but remediation requires a change window, a PR, a review, a deployment. Two hours of work.

With Checkov in CI/CD: the PR is blocked the moment the security group is created. Error message: `CKV_AWS_25: Ensure no security groups allow ingress from 0.0.0.0:0 to port 22`. The developer sees it immediately, fixes it in 2 minutes, never reaches prod.

**Finding a misconfiguration in code review costs minutes. Finding it in production costs hours — or worse.**

---

## Checkov — Comprehensive IaC Scanner

Checkov scans Terraform, CloudFormation, Kubernetes, and more. 1,000+ built-in security and compliance rules.

```bash
# Install
pip install checkov

# Basic scan
checkov -d . --framework terraform

# Example output:
# Check: CKV_AWS_16: "Ensure that RDS database is not publicly accessible"
# FAILED for resource: aws_db_instance.main
# File: /code/main.tf:45
# Guide: https://docs.bridgecrew.io/docs/bc_aws_general_2

# Check: CKV_AWS_53: "Ensure S3 bucket has block public ACLS"
# PASSED for resource: aws_s3_bucket.logs

# Passed checks: 12, Failed checks: 1

# Fail only on HIGH and CRITICAL, warn on lower
checkov -d . --framework terraform   --check CKV_AWS_16,CKV_AWS_17,CKV_AWS_53   --compact

# Output as SARIF (shows in GitHub Security tab)
checkov -d . --output sarif --output-file-path checkov-results.sarif
```

---

## tfsec — Fast Terraform-Specific Scanner

tfsec is faster than Checkov and focused purely on Terraform. Great for quick CI/CD checks.

```bash
# Install
brew install tfsec

# Scan
tfsec . --minimum-severity HIGH

# Ignore a specific rule inline (with justification)
#tfsec:ignore:aws-s3-enable-bucket-logging  -- internal bucket, logging not needed
resource "aws_s3_bucket" "build_artifacts" { ... }

# JSON output for CI/CD parsing
tfsec . --format json --out results.json

# Only fail on HIGH and CRITICAL
tfsec . --minimum-severity HIGH
```

---

## Most Critical Checkov Rules

| Check ID | Rule | Why It Matters |
|----------|------|---------------|
| `CKV_AWS_16` | RDS `publicly_accessible = false` | Database exposure |
| `CKV_AWS_17` | RDS `storage_encrypted = true` | Data at rest compliance |
| `CKV_AWS_18` | S3 access logging enabled | Audit trail |
| `CKV_AWS_21` | S3 versioning enabled | Data recovery |
| `CKV_AWS_53` | S3 public access block | Data exposure |
| `CKV_AWS_79` | EC2 not in default VPC | Security boundary |
| `CKV_AWS_23` | RDS `deletion_protection = true` | Prevent accidents |
| `CKV_AWS_25` | No SG ingress port 22 from 0.0.0.0/0 | Attack surface |
| `CKV_AWS_130` | S3 `server_side_encryption_configuration` | Data at rest |
| `CKV_AWS_3` | SG no unrestricted ingress | Attack surface |

---

## CI/CD Integration — GitHub Actions

```yaml
- name: Checkov Security Scan
  uses: bridgecrewio/checkov-action@master
  with:
    directory: .
    framework: terraform
    output_format: sarif
    output_file_path: checkov.sarif
    soft_fail: false    # fail the PR on findings

- name: Upload to GitHub Security Tab
  uses: github/codeql-action/upload-sarif@v2
  if: always()
  with:
    sarif_file: checkov.sarif
```

---

## CI/CD Integration — Jenkins

```groovy
stage("Security Scanning") {
  parallel {
    stage("Checkov") {
      steps { sh "checkov -d . --quiet --compact --framework terraform" }
    }
    stage("tfsec") {
      steps { sh "tfsec . --minimum-severity HIGH" }
    }
  }
}
```

Run both in parallel — total time ~30 seconds. Blocks any PR with HIGH or CRITICAL security findings.

---

## Writing Compliant Code From the Start

```hcl
# Follow these patterns and you'll pass most scans automatically

# S3: the checklist
resource "aws_s3_bucket" "example" { bucket = "..." }
resource "aws_s3_bucket_versioning" "example" {                             # CKV_AWS_21
  bucket = aws_s3_bucket.example.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {   # CKV_AWS_17
  bucket = aws_s3_bucket.example.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_public_access_block" "example" {                    # CKV_AWS_53
  bucket = aws_s3_bucket.example.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}
resource "aws_s3_bucket_logging" "example" {                                # CKV_AWS_18
  bucket = aws_s3_bucket.example.id
  target_bucket = aws_s3_bucket.example.id
  target_prefix = "logs/"
}
```
