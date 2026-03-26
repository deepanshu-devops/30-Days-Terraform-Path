# Day 19 — Security Scanning: Checkov & tfsec

## WHAT
Static analysis tools that scan Terraform code for security misconfigurations — before apply, in the IDE, and in CI/CD.

## Checkov

```bash
pip install checkov

# Scan a directory
checkov -d ./terraform --framework terraform

# Output formats
checkov -d . --output json        # JSON (for CI/CD integration)
checkov -d . --output sarif       # SARIF (for GitHub Security tab)
checkov -d . --output github_failed_only  # Only show failures

# Skip specific checks
checkov -d . --skip-check CKV_AWS_18,CKV_AWS_21

# Run specific checks only
checkov -d . --check CKV_AWS_2,CKV_AWS_3
```

**Common Checkov findings:**
| Check ID | Description |
|---|---|
| CKV_AWS_2 | ALB Listener uses HTTPS |
| CKV_AWS_18 | S3 bucket has access logging |
| CKV_AWS_21 | S3 bucket has versioning |
| CKV_AWS_53 | S3 bucket has public access blocked |
| CKV_AWS_16 | RDS database not publicly accessible |
| CKV_AWS_17 | RDS database storage encrypted |
| CKV_AWS_23 | RDS has deletion protection |
| CKV_AWS_79 | EC2 not using default VPC |

## tfsec

```bash
# Install
brew install tfsec
# or
go install github.com/aquasecurity/tfsec/cmd/tfsec@latest

# Basic scan
tfsec ./terraform

# Filter by severity
tfsec . --minimum-severity HIGH

# Output as JSON
tfsec . --format json

# Ignore specific rule in code:
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "internal_only" { ... }
```

## In CI/CD (GitHub Actions)

```yaml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
    output_format: sarif
    output_file_path: checkov-results.sarif
    soft_fail: false

- name: Upload Checkov results to GitHub Security
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: checkov-results.sarif

- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: terraform/
    minimum_severity: HIGH
```

## Trivy (Emerging Standard)

```bash
# Trivy now covers IaC scanning (replaces tfsec from Aqua Security)
trivy config ./terraform

# With severity filter
trivy config --severity HIGH,CRITICAL ./terraform
```

---

## Audience Levels

### 🟢 Beginner
Run `checkov -d .` in your Terraform directory right now. It will show you every security issue. Fix them one by one. It teaches you security as you go.

### 🔵 Intermediate
Add Checkov and tfsec to your PR pipeline. Configure HIGH and CRITICAL findings to block merge. MEDIUM findings as warnings. Review the findings list — some may be false positives for your context.

### 🟠 Advanced
Build a custom Checkov check for your organization's specific rules (e.g., required tags, specific KMS keys). Checkov supports custom Python checks.

### 🔴 Expert
Feed Checkov/tfsec SARIF output into GitHub Code Scanning or SonarQube. Track security debt over time. Build a policy exception workflow: teams can request exceptions with business justification, tracked as GitHub issues.
