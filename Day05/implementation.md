# Day 05 — Implementation: Variables, Outputs & Locals

## Hands-On Steps

### 1. Use default values
```bash
cd Day05/code
terraform init
terraform plan  # Uses all defaults
terraform apply -auto-approve
terraform output  # See all outputs
terraform output subnet_ids  # See specific output
terraform output -json  # JSON format for scripting
```

### 2. Override variables
```bash
# Via CLI flag
terraform plan -var="environment=staging" -var="subnet_count=3"

# Via tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform plan

# Via environment variable
export TF_VAR_environment=staging
terraform plan
```

### 3. See validation in action
```bash
terraform plan -var="environment=invalid"
# Error: Environment must be dev, staging, or production.

terraform plan -var="subnet_count=10"
# Error: Subnet count must be between 1 and 6.
```

### 4. Inspect locals via console
```bash
terraform console
> local.name_prefix
> local.common_tags
> local.subnet_cidrs
> local.instance_type
```

### 5. Clean up
```bash
terraform destroy -auto-approve
```

## Key Patterns

| Need | Use |
|---|---|
| External input | `variable` |
| Computed/reused internal value | `local` |
| Expose value to callers or scripts | `output` |
| Pass secrets | `variable` with `sensitive = true` |
| Environment-specific values | separate `.tfvars` files |
