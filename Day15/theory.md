# Day 15 — Terraform in CI/CD: Jenkins & GitHub Actions

## WHAT
CI/CD for Terraform automates the plan/apply workflow so no engineer manually applies changes to production.

## The Golden Rule
**Plan on PR. Apply on merge. Human approval gate in between.**

## GitHub Actions Pipeline

### Full workflow (.github/workflows/terraform.yml):
```yaml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]
    paths: ["terraform/**"]
  push:
    branches: [main]
    paths: ["terraform/**"]

env:
  TF_VERSION: "1.6.0"
  AWS_REGION: "us-east-1"

jobs:
  terraform:
    name: Terraform
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write  # For OIDC auth with AWS

    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/TerraformCIRole
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform

      - name: Terraform Init
        run: terraform init
        working-directory: terraform

      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        working-directory: terraform
        continue-on-error: true

      - name: Comment Plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📋
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            `;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform
```

## Jenkins Pipeline (Declarative)

```groovy
pipeline {
    agent any
    environment {
        TF_VERSION = "1.6.0"
        AWS_REGION = "us-east-1"
    }
    stages {
        stage("Checkout") {
            steps { checkout scm }
        }
        stage("Setup") {
            steps {
                sh """
                    wget -q https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
                    unzip -o terraform_${TF_VERSION}_linux_amd64.zip
                    mv terraform /usr/local/bin/
                """
            }
        }
        stage("Init") {
            steps {
                withAWS(role: "TerraformCIRole", region: env.AWS_REGION) {
                    sh "terraform init"
                }
            }
        }
        stage("Plan") {
            steps {
                withAWS(role: "TerraformCIRole", region: env.AWS_REGION) {
                    sh "terraform plan -no-color -out=tfplan 2>&1 | tee plan.txt"
                    archiveArtifacts "tfplan,plan.txt"
                }
            }
        }
        stage("Approval") {
            when { branch "main" }
            steps {
                input message: "Review plan.txt and approve to apply", ok: "Apply"
            }
        }
        stage("Apply") {
            when { branch "main" }
            steps {
                withAWS(role: "TerraformCIRole", region: env.AWS_REGION) {
                    sh "terraform apply tfplan"
                }
            }
        }
    }
    post {
        failure { emailext subject: "Terraform Apply Failed", body: "${env.BUILD_URL}", to: "team@company.com" }
    }
}
```

## Best Practices

| Practice | Why |
|---|---|
| OIDC authentication (no static keys) | Keys can be leaked; OIDC is ephemeral |
| Post plan as PR comment | Reviewers see impact before approving |
| `-no-color` flag | Avoids ANSI escape codes in logs |
| Archive plan file | Ensures apply == reviewed plan |
| Human approval gate on main | Last line of defence |
| `terraform fmt -check` | Enforce consistent formatting |
| Run in PR environment | Catch issues before merge |

## Audience Levels

### 🟢 Beginner
CI/CD means no one runs `terraform apply` by hand. The pipeline does it. Code review + CI = safety.

### 🔵 Intermediate
Use OIDC for AWS authentication instead of access keys. GitHub Actions and AWS OIDC integration means no secrets stored in GitHub.

### 🟠 Advanced
Use Atlantis for GitOps Terraform. Atlantis runs as a server, comments `terraform plan` results on PRs, and applies on PR merge — all with full audit logs.

### 🔴 Expert
Build a promotion pipeline: dev auto-applies on merge, staging requires 1 approval, prod requires 2 approvals + change window check (no applies on Fridays). Use plan output to auto-estimate cost with Infracost in the PR comment.
