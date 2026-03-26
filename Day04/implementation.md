# Day 04 — Implementation: Lifecycle Commands

## Practice the Full Lifecycle

```bash
cd Day04/code

# Step 1: Initialize
terraform init
# Verify: .terraform/ directory created, .terraform.lock.hcl created

# Step 2: Validate
terraform validate
# Expected: "Success! The configuration is valid."

# Step 3: Format
terraform fmt
# Aligns your code consistently

# Step 4: Plan
terraform plan -out=day04.tfplan
# Review: Should see 3 resources to create (vpc + 2 subnets)

# Step 5: Inspect the saved plan
terraform show day04.tfplan

# Step 6: Apply the saved plan
terraform apply day04.tfplan
# No prompt needed — plan was already reviewed

# Step 7: Run plan again — should show no changes
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."

# Step 8: Simulate drift — manually edit a subnet tag in AWS Console
# Then run:
terraform plan
# Expected: shows ~ update for the subnet with changed tag

# Step 9: Apply to fix drift
terraform apply -auto-approve  # OK for learning, never in prod

# Step 10: Preview destroy
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan  # Review what will be deleted

# Step 11: Destroy
terraform apply destroy.tfplan
```

## CI/CD Pattern (GitHub Actions)

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Init
        run: terraform init

      - name: Validate
        run: terraform validate

      - name: Plan (on PR)
        if: github.event_name == 'pull_request'
        run: terraform plan -no-color -out=tfplan

      - name: Apply (on merge to main)
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
```
