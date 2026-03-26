# Day 04 — Init → Plan → Apply → Destroy Lifecycle

## 5W + 1H Framework

### WHO
Every Terraform user — this is the daily workflow.

### WHAT
The four core Terraform commands form a complete lifecycle:

| Command | Action | Touches Real Infra? |
|---|---|---|
| `terraform init` | Download providers/modules, set up backend | No |
| `terraform plan` | Preview changes | No (read-only API calls) |
| `terraform apply` | Execute changes | YES |
| `terraform destroy` | Delete all managed resources | YES (destructive) |

### WHEN
- `init`: First time, after adding providers/modules, after backend changes
- `plan`: Before every apply — always
- `apply`: After reviewing the plan — intentionally
- `destroy`: Cleanup of temporary environments; NEVER in production without extreme care

### WHERE
- Run locally during development
- Run in CI/CD pipelines (GitHub Actions, Jenkins, GitLab CI) for production

### WHY
- **init** ensures consistent provider versions across team
- **plan** is the safety net — the diff between desired and current state
- **apply** is the execution — always after human or automated review
- **destroy** enables ephemeral environments (dev/test spun up and torn down)

### HOW
Each command in depth below.

---

## Command Deep-Dives

### `terraform init`

```bash
terraform init

# Flags:
terraform init -upgrade          # Upgrade provider versions within constraints
terraform init -reconfigure      # Force reconfiguration of backend
terraform init -migrate-state    # Migrate state from old backend to new
terraform init -backend=false    # Skip backend configuration
terraform init -get=false        # Skip module downloads
```

What `init` does:
1. Reads `required_providers` block
2. Downloads providers to `.terraform/providers/`
3. Creates/updates `.terraform.lock.hcl` with exact checksums
4. Reads `backend {}` block, initializes the state backend
5. Downloads any `module {}` sources

### `terraform plan`

```bash
terraform plan

# Flags:
terraform plan -out=tfplan           # Save plan for later apply (recommended in CI/CD)
terraform plan -var="env=prod"       # Override a variable
terraform plan -var-file="prod.tfvars" # Use a specific var file
terraform plan -target=aws_vpc.main  # Plan only this resource
terraform plan -refresh=false        # Skip refreshing state from real infra
terraform plan -destroy              # Preview what destroy would do
```

Plan symbols:
```
+ create       # New resource
~ update       # In-place update (no replacement)
-/+ replace    # Destroy + recreate (e.g., renaming an S3 bucket)
- destroy      # Resource will be deleted
```

### `terraform apply`

```bash
terraform apply

# Flags:
terraform apply tfplan               # Apply a saved plan (deterministic)
terraform apply -auto-approve        # Skip interactive approval (CI/CD only)
terraform apply -target=aws_vpc.main # Apply only this resource
terraform apply -parallelism=20      # Run 20 concurrent operations (default: 10)
```

**NEVER use `-auto-approve` in production without a human approval gate in CI/CD.**

### `terraform destroy`

```bash
terraform destroy

# Flags:
terraform destroy -target=aws_instance.web  # Destroy only one resource
terraform destroy -auto-approve              # Skip approval (use with extreme caution)

# Safer alternative: plan the destruction first
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

---

## Audience-Level Explanations

### 🟢 Beginner
Think of it like cooking:
- `init` = gather your ingredients (providers)
- `plan` = read the recipe and decide what to prepare
- `apply` = cook the meal
- `destroy` = clean up the kitchen (delete everything)

Always read the recipe (`plan`) before cooking (`apply`). Never skip it.

### 🔵 Intermediate
The plan/apply separation is crucial for team safety. In CI/CD:
- **Plan** runs on PR open (anyone can see the diff)
- **Apply** runs on merge to main (after PR approval)

Saving plans with `-out=tfplan` ensures what you reviewed is exactly what gets applied:
```bash
terraform plan -out=tfplan     # Saved binary plan
terraform apply tfplan          # Apply exactly that plan (no prompt)
```

### 🟠 Advanced
**Partial applies with `-target`:**
Use `-target` sparingly — it can leave your state inconsistent if resources have dependencies. Only use for:
- Bootstrapping (creating the S3 backend bucket itself)
- Emergency recovery
- Testing a single module during development

**Refresh behavior:**
During plan, Terraform calls cloud APIs to check real resource state. Disable with `-refresh=false` for speed (dangerous — you may apply against stale state).

```bash
# New in Terraform 1.4+: refresh only (no plan)
terraform apply -refresh-only
```

### 🔴 Expert
**Plan file format:**
The `-out` plan file is a binary protobuf (not JSON). To inspect:
```bash
terraform show -json tfplan | jq '.resource_changes[] | {addr: .address, action: .change.actions}'
```

**Parallelism tuning:**
Default parallelism=10. AWS API rate limits vary by service:
- EC2: 200 req/sec
- IAM: 20 req/sec
- Route53: 5 req/sec
Tune `-parallelism` down if you hit ThrottlingException errors.

**State refresh internals:**
During plan, Terraform calls `provider.ReadResource()` for every managed resource. For 1000 resources, this is 1000 API calls — takes minutes. Use workspaces or separate root modules to keep state sizes manageable.
