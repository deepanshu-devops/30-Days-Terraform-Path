# Day 05 — Variables, Outputs & Locals

## 5W + 1H

### WHAT

#### Variables (Inputs)
Variables allow external values to be passed into Terraform configuration.

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Must be dev, staging, or production."
  }
}
```

**Variable types:**
```hcl
variable "string_var"  { type = string }
variable "number_var"  { type = number }
variable "bool_var"    { type = bool }
variable "list_var"    { type = list(string) }
variable "map_var"     { type = map(string) }
variable "set_var"     { type = set(string) }
variable "tuple_var"   { type = tuple([string, number, bool]) }
variable "object_var"  {
  type = object({
    name     = string
    port     = number
    enabled  = bool
  })
}
```

**Variable precedence (highest wins):**
1. `-var` CLI flag
2. `-var-file` CLI flag  
3. `*.auto.tfvars` files (alphabetical)
4. `terraform.tfvars`
5. Environment variables (`TF_VAR_name`)
6. Default value in variable block

#### Locals (Computed Values)
Locals are named values computed within the configuration — not inputs, not outputs.

```hcl
locals {
  # Simple computed value
  name_prefix = "${var.project}-${var.environment}"
  
  # Conditional
  instance_type = var.environment == "production" ? "t3.large" : "t3.micro"
  
  # Map of common tags — DRY principle
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
  }
  
  # Computed from data sources
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}
```

#### Outputs (Exports)
Outputs expose values after apply — for humans, scripts, or other Terraform modules.

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "database_password" {
  description = "The database password (sensitive)"
  value       = aws_db_instance.main.password
  sensitive   = true  # Redacted in plan/apply output; still in state
}

# Structured output
output "subnet_ids" {
  description = "List of all subnet IDs"
  value       = aws_subnet.main[*].id
}
```

---

## Audience-Level Explanations

### 🟢 Beginner
Variables = function parameters. Outputs = function return values. Locals = local variables inside the function.

```hcl
# Without variables (bad):
resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16" }
resource "aws_vpc" "prod" { cidr_block = "10.1.0.0/16" }  # Copy-paste!

# With variables (good):
variable "cidr_block" { type = string }
resource "aws_vpc" "main" { cidr_block = var.cidr_block }
```

### 🔵 Intermediate

**terraform.tfvars pattern for multi-environment:**
```
environments/
  dev.tfvars      # environment = "dev", instance_type = "t3.micro"
  staging.tfvars  # environment = "staging", instance_type = "t3.small"
  prod.tfvars     # environment = "production", instance_type = "t3.large"
```

```bash
terraform apply -var-file="prod.tfvars"
```

**Environment variable injection (for CI/CD secrets):**
```bash
export TF_VAR_db_password="supersecret"
terraform apply  # Picks up TF_VAR_db_password automatically
```

### 🟠 Advanced

**Complex variable types with defaults:**
```hcl
variable "node_groups" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  }))
  default = {
    general = {
      instance_type = "t3.medium"
      min_size      = 2
      max_size      = 10
      desired_size  = 3
    }
    memory = {
      instance_type = "r6i.large"
      min_size      = 1
      max_size      = 5
      desired_size  = 2
    }
  }
}
```

**Output dependencies:**
Outputs can reference any resource attribute, including computed ones:
```hcl
output "alb_dns_name" {
  value = aws_lb.main.dns_name  # Known only after apply
}
```

### 🔴 Expert

**Sensitive values handling:**
- `sensitive = true` on a variable: value is redacted in logs
- `sensitive = true` on an output: value is redacted in plan output
- Values are still in `.tfstate` — state itself must be encrypted
- Use `nonsensitive()` builtin to explicitly unseal in contexts where you need to reference it

**Variable validation with regex:**
```hcl
variable "bucket_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,63}$", var.bucket_name))
    error_message = "Bucket name must be 3-63 chars, lowercase letters, numbers, hyphens."
  }
}
```

**Output cross-module sharing:**
```hcl
# Root module: expose subnet IDs
output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# In another root module: consume via remote state
data "terraform_remote_state" "network" {
  backend = "s3"
  config  = { bucket = "my-state", key = "network/terraform.tfstate", region = "us-east-1" }
}

module "eks" {
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
```
