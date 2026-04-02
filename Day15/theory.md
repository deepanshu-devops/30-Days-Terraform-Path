# Day 15 — Terraform in CI/CD: GitHub Actions & Jenkins

## Real-Life Example 🏗️

**The Manual Apply Problem:**  
Your team has 6 engineers. Three of them have production AWS access. Anyone can run `terraform apply` from their laptop at any time. This month:

1. Engineer A applies a 2-week-old branch to prod (forgot to pull latest) → two resources recreated → 15-minute outage
2. Engineer B selects the wrong workspace, applies dev config to staging → wrong VPC CIDR → 2 hours to fix
3. No audit trail: "Who applied this at 11pm?" No one knows

**The pipeline solution:**  
- No engineer applies manually to production. Ever.
- Every change goes: PR → pipeline runs `terraform plan` → plan posted as PR comment → peer review → merge → pipeline applies
- Full audit trail: every apply is a Git commit with author, timestamp, and the exact plan that was applied

---

## The CI/CD Workflow

```
Developer pushes branch
         │
         ▼
Pull Request opened
         │
         ▼
Pipeline: terraform fmt --check    ← fail if code not formatted
          terraform validate       ← fail if syntax error
          terraform plan -out=plan ← preview changes
          Post plan as PR comment  ← team sees impact
         │
         ▼
Peer review + plan review
         │
    Approved?
    ├── No → request changes
    └── Yes → merge to main
               │
               ▼
           Pipeline: terraform apply plan
                        │
                        ▼
                     Done. Git commit = audit trail.
```

---

## GitHub Actions — Full Pipeline

See `Day15/code/.github/workflows/terraform.yml` for the complete file. Key concepts:

### OIDC Authentication (No Static Keys)
```yaml
permissions:
  id-token: write   # Required for OIDC

- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/TerraformCIRole
    aws-region: us-east-1
```

GitHub Actions exchanges a short-lived OIDC token for temporary AWS credentials. No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` stored anywhere. If the credentials leak, they expire in 15 minutes.

### Post Plan as PR Comment
```yaml
- name: Comment Plan on PR
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        body: "#### Terraform Plan
```
" + plan + "
```"
      })
```

Reviewers see the exact resources that will be created/changed/destroyed before they approve.

### Apply Only on Merge to Main
```yaml
- name: Terraform Apply
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: terraform apply -auto-approve tfplan
```

`apply` never runs on PRs — only after merge. The plan file from the PR is applied on merge, ensuring what was reviewed is exactly what gets applied.

---

## Jenkins — Jenkinsfile

See `Day15/code/Jenkinsfile` for the complete pipeline. Key concepts:

### Human Approval Gate
```groovy
stage("Human Approval") {
  when { branch "main" }
  steps {
    input message: "Review plan output and approve to apply", ok: "Approve"
  }
}
```

Jenkins pauses and sends a notification. An engineer reviews the plan and explicitly approves before apply runs.

### withAWS Role Assumption
```groovy
withAWS(role: "TerraformCIRole", region: "us-east-1") {
  sh "terraform apply tfplan"
}
```

No stored access keys — Jenkins assumes an IAM role per-run.

---

## Required CI/CD Checklist

```yaml
# Run on every PR:
✅ terraform fmt -check    # Catches unformatted code
✅ terraform validate      # Catches syntax/logic errors
✅ terraform plan -out     # Shows what will change
✅ Post plan as comment    # Enables informed code review
✅ checkov / tfsec         # Security scanning (Day 19)

# Run on merge to main:
✅ terraform apply tfplan  # Applies the exact reviewed plan
✅ terraform output        # Print outputs for reference

# NEVER:
❌ terraform apply without reviewing plan
❌ terraform apply -auto-approve in production without a prior human review step
❌ Hardcoded AWS credentials in pipeline config
```

---

## Setting Up OIDC (One-Time)

```hcl
# In your IAM Terraform config (Day 17):
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

Add to GitHub repository secrets:
- `AWS_ACCOUNT_ID` = your 12-digit AWS account number

That's it. No access keys needed.
