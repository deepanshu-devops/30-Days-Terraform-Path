# Day 10 — Writing Reusable Terraform Modules

## Real-Life Example 🏗️

**The Copy-Paste Problem:**  
You build a VPC for Team A. Team B asks for a VPC. You copy-paste the code, change a few names. Team C, D, E — same thing.

Six months later: security finds a missing flow log configuration. You need to add it to all six VPC codebases. You'll update five and forget one. That sixth VPC is now non-compliant.

**The Module Solution:**  
Fix the VPC module once → all six teams get the fix on their next `terraform apply`.

At Amdocs, this single change — from copy-paste to modules — reduced provisioning time from 48 hours to 30 minutes.

---

## What is a Module?

A module is just **a folder of `.tf` files** designed to be called by other configurations.

Every Terraform configuration is technically a module (the "root module"). A _reusable_ module is one explicitly structured for calling from multiple places.

```
modules/
  vpc/
    variables.tf   ← module inputs (the public API)
    main.tf        ← resources (the implementation)
    outputs.tf     ← module outputs (what callers receive)
    # NO provider.tf — modules never define providers
    # NO backend    — modules never define state
```

---

## The Three Module Files

### `variables.tf` — The Module's Input API

```hcl
# Everything a caller must or can provide
variable "name" {
  description = "Name prefix for all resources created by this module"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway. Costs ~$32/month. Set false for dev."
  type        = bool
  default     = false
}
```

### `main.tf` — The Implementation

```hcl
# No provider block. No backend block.
# Resources use var.x for inputs, output to outputs.tf

locals {
  common_tags = { ManagedBy = "Terraform", Module = "vpc" }
}

resource "aws_vpc" "this" {          # "this" is the convention for single-instance module resources
  cidr_block = var.vpc_cidr
  tags       = merge(local.common_tags, { Name = "${var.name}-vpc" })
}
```

### `outputs.tf` — What the Module Returns

```hcl
output "vpc_id" {
  description = "VPC ID — pass to EKS, RDS, ALB modules"
  value       = aws_vpc.this.id
}
output "private_subnet_ids" {
  description = "Private subnet IDs for EKS node groups and RDS"
  value       = aws_subnet.private[*].id
}
```

---

## Calling a Module

```hcl
# Local path (development — no version pinning)
module "vpc" {
  source = "./modules/vpc"
  name   = "myapp-prod"
  vpc_cidr = "10.0.0.0/16"
}

# Git tag (production — ALWAYS use a version tag)
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.0"
  name   = "myapp-prod"
}

# Terraform Registry (community modules)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"    # exact version — never omit this
  name    = "myapp-prod"
}

# After adding ANY module call: run terraform init
terraform init    # downloads the module
```

---

## Accessing Module Outputs

```hcl
# In main.tf of the calling (root) module:
module "vpc" {
  source = "./modules/vpc"
  name   = "myapp"
}

# Access module outputs with: module.<name>.<output_name>
resource "aws_eks_cluster" "main" {
  vpc_config {
    subnet_ids = module.vpc.private_subnet_ids    # ← module output
    vpc_id     = module.vpc.vpc_id                # ← module output
  }
}
```

---

## Module Design Principles

| Principle | Example |
|-----------|---------|
| **Single responsibility** | VPC module creates only VPC resources — not EKS |
| **Sensible defaults** | `enable_nat_gateway = false` saves money in dev |
| **No hardcoded values** | Everything comes from `var.x` |
| **Documented API** | Every variable and output has a `description` |
| **Named "this" for singletons** | `resource "aws_vpc" "this"` — standard Go-style convention |
| **No provider or backend** | Caller controls these |

---

## Module vs Root Module — What's Different

| | Root Module | Reusable Module |
|--|--|--|
| Has `provider.tf`? | ✅ Yes | ❌ No |
| Has `backend`? | ✅ Yes | ❌ No |
| Has `terraform.tfvars`? | ✅ Yes | ❌ No |
| Called by? | `terraform apply` | `module "name" { source = ... }` |
| State stored? | ✅ Yes | ❌ No (caller's state) |
