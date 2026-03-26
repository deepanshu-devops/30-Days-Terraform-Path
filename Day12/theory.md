# Day 12 — Workspaces vs tfvars for Environments

## WHAT

### Workspaces
Workspaces create separate state files for the same configuration directory.

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new production
terraform workspace list
terraform workspace select production
terraform apply  # Uses production workspace state
```

In config, reference current workspace:
```hcl
locals {
  instance_type = {
    dev        = "t3.micro"
    staging    = "t3.small"
    production = "t3.large"
  }[terraform.workspace]
}
```

### tfvars-per-environment (Recommended)

```
environments/
  dev/
    main.tf          # module calls
    backend.tf       # dev backend config
    terraform.tfvars # dev-specific variable values
  staging/
    main.tf
    backend.tf
    terraform.tfvars
  prod/
    main.tf
    backend.tf
    terraform.tfvars
```

Each environment:
- Has its own Terraform root module
- Has its own state
- Has its own backend key
- Can have wildly different resources

## Decision Matrix

| Factor | Workspaces | tfvars per env |
|---|---|---|
| Completely different infra per env | ❌ Hard | ✅ Easy |
| Separate blast radius | ❌ Shares backend | ✅ Separate states |
| Production isolation | ❌ Same code dir | ✅ Separate directory |
| Simplicity (same infra everywhere) | ✅ Simple | ⚠️ More files |
| Drift between envs | ❌ Hard to see | ✅ Explicit |

**Recommendation:** Workspaces for non-prod (dev/staging) identical configs. tfvars per env for production and environments that differ significantly.

## Audience Levels

### 🟢 Beginner
Use workspaces for learning. For production, use separate directories — it's safer and easier to audit.

### 🔵 Intermediate
The key insight: with workspaces, a mistake in workspace selection (`terraform workspace select prod` → runs against prod accidentally) is dangerous. Separate directories have natural blast-radius isolation.

### 🟠 Advanced
**Atlantis** (GitOps for Terraform) works well with directory-per-env. PRs to `environments/prod/` trigger plan against prod. PRs to `environments/dev/` trigger plan against dev.

### 🔴 Expert
At scale, consider a layered architecture: base layer (networking), compute layer (EKS/EC2), application layer (app resources). Each layer has its own state. Each environment has its own copy. Cross-layer references via remote state data sources.
