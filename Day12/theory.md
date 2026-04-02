# Day 12 — Workspaces vs tfvars for Environment Management

## Real-Life Example 🏗️

**The environment management question every team hits:**
You have dev, staging, and prod. All need a VPC but with different configurations.

- Dev: 1 subnet, t3.micro, no NAT (cost: ~$5/month)
- Staging: 2 subnets, t3.small, no NAT (cost: ~$15/month)
- Prod: 3 subnets, t3.large, NAT gateway HA across 3 AZs (cost: ~$120/month)

You have two tools. Pick the right one.

---

## Option A: Terraform Workspaces

Workspaces create isolated state files while using the same code directory.

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch and apply
terraform workspace select staging
terraform apply
# Deploys staging — state key: env:/staging/terraform.tfstate

terraform workspace select prod
terraform apply
# Deploys prod — state key: env:/prod/terraform.tfstate

# See all workspaces
terraform workspace list
# * dev
#   staging
#   prod    ← current workspace marked with *

terraform workspace show    # "prod"
```

In your code, reference the current workspace:
```hcl
locals {
  # Different config per workspace — all in one place
  workspace_config = {
    dev     = { instance_type = "t3.micro",  nat_count = 0, subnet_count = 1 }
    staging = { instance_type = "t3.small",  nat_count = 0, subnet_count = 2 }
    prod    = { instance_type = "t3.large",  nat_count = 3, subnet_count = 3 }
  }

  config = local.workspace_config[terraform.workspace]
}

resource "aws_instance" "web" {
  instance_type = local.config.instance_type
  # "dev" workspace → "t3.micro"
  # "prod" workspace → "t3.large"
}
```

**When to use workspaces:**
- ✅ Dev and staging with identical infra structure
- ✅ Quick isolation without creating more directories
- ✅ Feature branch environments that are short-lived
- ❌ Production (wrong workspace selection = prod apply from dev context)
- ❌ Environments with significantly different infrastructure
- ❌ When you need completely separate state backends

---

## Option B: Separate tfvars Files (Recommended for Production)

Each environment has its own variable file with different values.

```
code/
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── envs/
    ├── dev.tfvars          # cheap settings
    ├── staging.tfvars      # medium settings
    └── prod.tfvars         # HA, expensive settings
```

```bash
# Apply per environment
terraform apply -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/staging.tfvars"
terraform apply -var-file="envs/prod.tfvars"
```

`envs/prod.tfvars`:
```hcl
aws_region    = "us-east-1"
environment   = "prod"
instance_type = "t3.large"
subnet_count  = 3
enable_nat    = true
```

**When to use tfvars:**
- ✅ Production — different command = natural safety barrier
- ✅ Environments with significantly different infrastructure
- ✅ When you want separate state files with separate backend keys
- ✅ CI/CD pipelines (dev pipeline uses dev.tfvars, prod pipeline uses prod.tfvars)
- ✅ Auditing — it's crystal clear which values are being applied

---

## Comparison Table

| Feature | Workspaces | tfvars per env |
|---------|-----------|----------------|
| Separate state | ✅ Yes | ✅ Yes (different S3 key) |
| Different infra per env | ⚠️ Needs conditionals | ✅ Natural |
| Production safety | ❌ One `workspace select` mistake = prod apply | ✅ Explicit `-var-file=prod.tfvars` |
| Simplicity | ✅ Less files | ⚠️ More files |
| CI/CD integration | `terraform workspace select prod` | `terraform apply -var-file=envs/prod.tfvars` |
| Code review clarity | ⚠️ Logic mixed in locals | ✅ Separate files, clear diff |

---

## Recommendation

```
Workspaces:  dev and staging with IDENTICAL infra structure
tfvars:      ALWAYS for production, always for envs that differ
```

At Amdocs: every project uses separate tfvars files per environment. Production has its own backend key, its own CI/CD pipeline, and requires a separate approval step. The workspace approach is too easy to accidentally run in the wrong context.

---

## CI/CD Pattern with tfvars

```yaml
# GitHub Actions — explicit environments, no workspace confusion
- name: Plan Dev
  run: terraform plan -var-file="envs/dev.tfvars" -out=dev.tfplan

- name: Plan Production
  run: terraform plan -var-file="envs/prod.tfvars" -out=prod.tfplan

- name: Apply Production (requires manual approval)
  environment: production    # GitHub environment protection rules
  run: terraform apply prod.tfplan
```
