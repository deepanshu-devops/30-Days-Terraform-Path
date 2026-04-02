# Day 05 — Variables, Outputs & Locals

## Real-Life Example 🏗️

**Scenario:** You manage infrastructure for three environments — dev, staging, and production — all with the same network layout but different sizes.

**Without variables:** Three separate copies of nearly identical code. Fix one bug → update three files → miss one → it breaks.

**With variables + tfvars:**
```bash
terraform apply -var-file="envs/dev.tfvars"     # cheap: t3.micro, 1 subnet
terraform apply -var-file="envs/staging.tfvars" # medium: t3.small, 2 subnets
terraform apply -var-file="envs/prod.tfvars"    # HA: t3.large, 3 subnets, NAT
```

One codebase. Three environments. Zero duplication.

---

## Variables — Inputs to Your Configuration

Variables are parameters your Terraform configuration accepts from outside.

### Basic Syntax
```hcl
variable "environment" {
  description = "Deployment environment — drives instance sizing and HA"
  type        = string
  default     = "dev"    # optional — if omitted, Terraform will prompt you
}

# Reference: var.environment
```

### All Variable Types
```hcl
variable "name"      { type = string }                     # "my-app"
variable "port"      { type = number }                     # 8080
variable "enabled"   { type = bool   }                     # true
variable "zones"     { type = list(string) }               # ["us-east-1a", "us-east-1b"]
variable "tags"      { type = map(string) }                # {env="dev", team="platform"}
variable "db_config" {
  type = object({
    engine  = string
    version = string
    size    = string
  })
  default = { engine = "postgres", version = "15.4", size = "db.t3.micro" }
}
```

### Validation — Catch Mistakes at Plan Time
```hcl
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod. Got: ${var.environment}"
  }
}

variable "vpc_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block like 10.0.0.0/16."
  }
}
```

If someone passes `environment = "production"` (instead of `prod`), they get a clear error message at plan time — not a confusing AWS error after 5 minutes of resource creation.

### How to Pass Values — Priority Order (highest wins)

| Priority | Method | Example |
|----------|--------|---------|
| 1 (highest) | `-var` CLI flag | `terraform apply -var="env=prod"` |
| 2 | `-var-file` CLI flag | `terraform apply -var-file="prod.tfvars"` |
| 3 | `*.auto.tfvars` files | auto-loaded alphabetically |
| 4 | `terraform.tfvars` | auto-loaded if present |
| 5 | `TF_VAR_name` env var | `export TF_VAR_db_password="secret"` |
| 6 (lowest) | `default` in variable block | fallback when nothing else set |

**For CI/CD secrets:** Use environment variables so nothing is written to disk:
```bash
export TF_VAR_db_password="$(aws secretsmanager get-secret-value   --secret-id prod/db/password --query SecretString --output text)"
terraform apply
```

---

## Locals — Internal Computed Values

Locals are named values you compute once inside the configuration and reference anywhere. They are not inputs (users can't override them) and not outputs (they don't appear after apply).

```hcl
locals {
  # Build a consistent name prefix — used in every resource name
  name_prefix = "${var.project}-${var.environment}"

  # Environment-driven sizing — decide once, use everywhere
  instance_type  = var.environment == "prod" ? "t3.large" : "t3.micro"
  subnet_count   = var.environment == "prod" ? 3 : 2
  multi_az       = var.environment == "prod"

  # Merge default tags with user-supplied extras
  # User-supplied tags win if there's a key conflict
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
    },
    var.additional_tags
  )

  # Compute subnet CIDRs automatically from the VPC CIDR
  subnet_cidrs = [
    for i in range(local.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
}

# Usage: local.name_prefix, local.instance_type, local.common_tags
```

**Why locals instead of repeating the expression?**
- Define `local.name_prefix` once → every resource name updates when you change `var.project`
- Define `local.common_tags` once → add a new required tag in one place, not 40 resource blocks

---

## Outputs — Values Exposed After Apply

Outputs are values Terraform prints after `apply`. They are readable by other modules and automation scripts.

```hcl
output "vpc_id" {
  description = "VPC ID — pass this to EKS, RDS, and ALB modules"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — required for EKS node groups and RDS"
  value       = aws_subnet.private[*].id
}

# Sensitive output — shown as <sensitive> in plan/apply
output "db_password" {
  description = "Database master password — accessible via: terraform output -raw db_password"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

### Reading Outputs After Apply
```bash
terraform output                        # all outputs (sensitive shown as <sensitive>)
terraform output vpc_id                 # single output value
terraform output -raw db_password       # raw value (no quotes — safe for scripting)
terraform output -json                  # all outputs as JSON for automation
```

### Cross-Module Output Sharing
```hcl
# In the VPC stack: output the subnet IDs
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# In the EKS stack: read the VPC stack's outputs
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config  = {
    bucket = "my-org-terraform-state"
    key    = "prod/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

module "eks" {
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```

---

## The Pattern: Variables → Locals → Outputs

```
variables.tf              main.tf                outputs.tf
────────────              ───────                ──────────
var.project      →   local.name_prefix    →   output "vpc_name"
var.environment  →   local.common_tags    →   output "common_tags"
var.vpc_cidr     →   aws_vpc.main         →   output "vpc_id"
var.subnet_count →   aws_subnet.public[n] →   output "subnet_ids"
```

---

## Testing Expressions with `terraform console`

Before writing a complex local or function, test it interactively:

```bash
terraform apply  # apply first so variables are loaded
terraform console

> var.environment
"dev"

> local.name_prefix
"day05-dev"

> local.subnet_cidrs
[
  "10.0.1.0/24",
  "10.0.2.0/24",
]

> cidrsubnet("10.0.0.0/16", 8, 5)
"10.0.5.0/24"

> merge({a=1}, {b=2, a=99})
{a=99, b=2}

> "prod" == "prod" ? "t3.large" : "t3.micro"
"t3.large"

> exit
```
