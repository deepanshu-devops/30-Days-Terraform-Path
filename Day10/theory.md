# Day 10 — Writing Your First Reusable Terraform Module

## WHAT
A Terraform module is a collection of `.tf` files in a directory. Every Terraform configuration is technically a module — the "root module". A reusable module is one explicitly designed for use by other configurations.

## Module Structure

```
modules/
  vpc/
    main.tf       # Core resources
    variables.tf  # Input variables (the module's API)
    outputs.tf    # Outputs exposed to callers
    versions.tf   # Required Terraform/provider versions
    README.md     # Documentation
```

## Module Design Principles

### 1. Single Responsibility
Each module does one thing well. A VPC module creates VPCs and subnets — not EKS clusters.

### 2. Opinionated Defaults
Provide sensible defaults. Callers should not have to specify obvious things.

### 3. Documented Inputs/Outputs
Every variable and output must have a `description`.

### 4. No Backend Configuration
Modules never define a backend. Only root modules do.

### 5. Version Constraints
Pin provider versions in `versions.tf` to protect module consumers.

---

## Example: VPC Module

### modules/vpc/versions.tf
```hcl
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}
```

### modules/vpc/variables.tf
```hcl
variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost saving for dev)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### modules/vpc/outputs.tf
```hcl
output "vpc_id"              { value = aws_vpc.this.id }
output "vpc_arn"             { value = aws_vpc.this.arn }
output "vpc_cidr_block"      { value = aws_vpc.this.cidr_block }
output "public_subnet_ids"   { value = aws_subnet.public[*].id }
output "private_subnet_ids"  { value = aws_subnet.private[*].id }
output "nat_gateway_ids"     { value = aws_nat_gateway.this[*].id }
output "internet_gateway_id" { value = aws_internet_gateway.this.id }
```

### Calling the Module
```hcl
module "vpc" {
  source = "./modules/vpc"  # Local path
  # OR: source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.0"

  name               = "myapp-prod"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false  # One per AZ for HA in production

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}

# Access module outputs
output "vpc_id"            { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
```

---

## Audience Levels

### 🟢 Beginner
A module is like a function. You call it with inputs (variables), it creates resources, and returns outputs. Instead of copy-pasting the same VPC code in every project, you write it once as a module and call it everywhere.

### 🔵 Intermediate
Build modules for your most common patterns: VPC, EKS, RDS, ALB, IAM roles. Track them in a separate Git repo (`terraform-modules`). Tag versions. Onboard new projects by calling the modules.

### 🟠 Advanced
Module composition: modules can call other modules. An "app module" can call VPC + EKS + RDS modules. Keep nesting shallow (2 levels max) to avoid dependency complexity.

### 🔴 Expert
Module testing with Terratest (Day 20). Contract testing: validate that module outputs exist and have expected types before releasing a new version. Use `terraform-docs` to auto-generate README from variable/output blocks.
