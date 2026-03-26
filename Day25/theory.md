# Day 25 — Drift Detection & How to Fix It

## WHAT
Drift = real infrastructure diverging from Terraform state. This happens when changes are made outside of Terraform (AWS Console, AWS CLI, another tool).

## Detecting Drift

### Manual Detection
```bash
# terraform plan always shows drift
terraform plan
# ~ update aws_security_group.web
#   tags["manual"] = null -> "added-outside-terraform"
```

### Automated: Scheduled Plan in GitHub Actions
```yaml
name: Drift Detection
on:
  schedule:
    - cron: '0 6 * * *'   # Every day at 6am UTC

jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform Init
        run: terraform init
      - name: Drift Check
        id: plan
        run: |
          terraform plan -detailed-exitcode -no-color 2>&1 | tee plan.txt
          echo "exit_code=$?" >> $GITHUB_OUTPUT
        continue-on-error: true
      - name: Notify on Drift
        if: steps.plan.outputs.exit_code == 2
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text": "⚠️ Terraform drift detected in ${{ github.repository }}. Review the plan output."}
```

`terraform plan -detailed-exitcode` exit codes:
- `0` = No changes
- `1` = Error
- `2` = Changes detected (drift)

### Terraform Cloud / HCP Terraform
Built-in health checks run automatically and alert on drift.

## Fixing Drift

### Option 1: Revert to code (code is truth)
```bash
terraform apply   # Brings infra back to what the code says
```

### Option 2: Codify the manual change (change is valid)
```hcl
# Update your Terraform code to include the manually-added change
# Then plan should show no changes
```

### Option 3: Import (bring the new resource into state)
```bash
terraform import aws_security_group.new sg-0newresource
```

## Prevention

| Practice | Effect |
|---|---|
| IAM: deny console write for managed resources | Hard prevention |
| AWS Config Rules: alert on changes | Detection |
| CloudTrail + SNS: real-time change notification | Detection |
| "No console cowboys" policy | Cultural |
| Scheduled drift detection | Systematic detection |

## Audience Levels

### 🟢 Beginner
Drift = someone changed something without going through Terraform. Run `terraform plan` regularly to catch it. Fix it by either reverting the change or updating your code.

### 🔵 Intermediate
Set up a nightly drift detection pipeline. Alert to Slack. Track drift as a metric — number of drift incidents per week. Treat drift as a bug.

### 🟠 Advanced
Use AWS Config with managed rules to detect drift in real-time (e.g., `required-tags`, `s3-bucket-public-read-prohibited`). Combine with SNS → Lambda → Terraform apply automation for auto-remediation of low-risk drift.

### 🔴 Expert
Build a GitOps model: all changes go through PRs. No human has console write access to production resources managed by Terraform. Use Service Control Policies to enforce this at the org level. Terraform is the only path to production change.
