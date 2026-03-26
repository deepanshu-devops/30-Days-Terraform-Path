# Day 08 — Implementation: Remote State Setup

## Step 1: Create the backend infrastructure

```bash
cd Day08/code
terraform init  # Uses local state for bootstrap
terraform apply
# Note the output: backend_config shows what to add to other projects
```

## Step 2: Migrate existing project to remote state

In your existing project's `main.tf`, add:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "projects/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

Then run:
```bash
terraform init -migrate-state
# Type "yes" when prompted
```

## Step 3: Verify

```bash
# State is now in S3
aws s3 ls s3://my-org-terraform-state/projects/vpc/

# Simulate concurrent access (in two terminals)
# Terminal 1:
terraform apply

# Terminal 2 (while Terminal 1 is running):
terraform apply
# Expected: Error acquiring the state lock (blocked correctly)
```

## Step 4: State backup and recovery

```bash
# Manual backup before risky operations
aws s3 cp s3://my-org-state/prod/vpc/terraform.tfstate ./backup.tfstate

# Restore from backup (use with extreme caution)
aws s3 cp ./backup.tfstate s3://my-org-state/prod/vpc/terraform.tfstate

# S3 versioning lets you restore via AWS Console or CLI
aws s3api list-object-versions --bucket my-org-state --prefix prod/vpc/terraform.tfstate
```
