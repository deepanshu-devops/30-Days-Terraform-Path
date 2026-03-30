# Day 03 — Providers, Resources & State

## Real-Life Example First 🏗️

**Scenario:** You join a startup as a DevOps engineer on day one.
The CTO says: *"We need a network in the US and one in EU for GDPR compliance — by tomorrow."*

Manually, that's 2 AWS Console sessions, 20+ clicks each, hoping you don't miss a setting.

With Terraform:
```bash
terraform apply   # Done. Both VPCs. Same settings. Every time.
```

That's the power of what you're learning today.

---

## The 3 Pillars: Provider, Resource, State

### 1. Provider — "Which cloud are we talking to?"

A **provider** is a plugin Terraform downloads to communicate with an API.

```hcl
# provider.tf
provider "aws" {
  region = "us-east-1"
}
```

Real-life analogy: A provider is like a **translator at the UN**.
You speak HCL. AWS speaks its own API. The provider translates.

- No provider → Terraform can't talk to any cloud
- Multiple providers → Terraform talks to AWS + Cloudflare + Datadog simultaneously
- Provider alias → same cloud, different region (us-east-1 AND eu-west-1)

**Multi-region example:**
```hcl
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

resource "aws_vpc" "eu" {
  provider   = aws.eu_west   # This VPC goes to Dublin
  cidr_block = "10.1.0.0/16"
}
```

---

### 2. Resource — "What infrastructure object do we want?"

A **resource** is one piece of infrastructure: a VPC, EC2, S3 bucket, IAM role.

```hcl
# Syntax: resource "TYPE" "NAME" { ... }
# TYPE = <provider>_<service>  e.g. aws_vpc, aws_s3_bucket
# NAME = your local label      used only inside Terraform

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Reference this resource anywhere: aws_vpc.main.id
```

**Real-life analogy:** Resources are **LEGO bricks**.
Each brick is independent but they snap together.
`aws_subnet` snaps onto `aws_vpc` because it needs `vpc_id`.

**Resource dependency (automatic):**
```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id   # Terraform sees this reference →
                              # creates VPC FIRST, then subnet
}
```

**Resource meta-arguments:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcdef"
  instance_type = "t3.micro"

  # lifecycle: control HOW Terraform handles this resource
  lifecycle {
    create_before_destroy = true  # new one before deleting old → zero downtime
    prevent_destroy       = true  # block terraform destroy on this resource
    ignore_changes        = [tags["LastUpdated"]]  # don't fight manual tag edits
  }
}
```

---

### 3. State — "What does Terraform remember?"

**State** is a JSON file (`terraform.tfstate`) that maps your HCL code to real AWS resource IDs.

```
Your Code               State File              Real AWS
──────────              ──────────              ────────
aws_vpc.main    →  →  vpc-0abc123456   →  →  VPC in AWS console
aws_subnet.pub  →  →  subnet-0def789   →  →  Subnet in AWS console
```

**Why state matters:**
- `terraform plan` compares: Code vs State vs Real infra → shows diff
- Without state: Terraform would recreate everything on every apply
- With state: Terraform knows "aws_vpc.main already exists as vpc-0abc123"

**The Golden Rules of State:**
| Rule | Why |
|------|-----|
| Never edit `.tfstate` by hand | Corrupts JSON → Terraform breaks |
| Always use remote state in teams | Local file → only you can apply |
| Enable S3 versioning on state bucket | Rollback if state gets corrupted |
| Enable DynamoDB locking | Prevents 2 people applying at once |

**State commands:**
```bash
terraform state list                   # what is Terraform tracking?
terraform state show aws_vpc.main      # details for one resource
terraform state rm aws_s3_bucket.old   # remove from state (real infra stays)
terraform state mv aws_vpc.old aws_vpc.new  # rename without destroy
```

---

## Data Sources — Read-Only Queries

Data sources let you **read** existing infrastructure without creating anything.

```hcl
# Real-life: You didn't create this VPC — another team did.
# You need its ID to put your subnets inside it.
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-services-vpc"]
  }
}

resource "aws_subnet" "app" {
  vpc_id = data.aws_vpc.shared.id   # Use the existing VPC
}
```

**Common data sources:**
```hcl
data "aws_caller_identity" "current" {}        # who am I?
data "aws_availability_zones" "available" {}   # which AZs exist?
data "aws_ami" "latest_linux" { ... }          # latest AMI ID
data "aws_secretsmanager_secret_version" "db" # fetch a secret
```

---

## Terraform Workflow for This Day

```bash
cd Day03/code

# 1. Download providers (reads provider.tf)
terraform init

# 2. Check for syntax errors
terraform validate

# 3. Auto-format all .tf files
terraform fmt

# 4. Preview what will be created
terraform plan

# 5. Create the infrastructure
terraform apply

# 6. Inspect state
terraform state list
terraform state show aws_vpc.us

# 7. Read outputs
terraform output
terraform output us_vpc_id

# 8. Cleanup
terraform destroy
```

---

## Common Mistakes & Fixes

| Mistake | Error | Fix |
|---------|-------|-----|
| Forgot `terraform init` | "Plugin not installed" | Run `terraform init` first |
| Wrong provider alias | "Provider not found" | Use `provider = aws.eu_west` |
| Deleted state file | Resources orphaned | Restore from S3 version |
| Two people applied at once | State corruption | Enable DynamoDB locking |
| Hardcoded region | Not portable | Use `var.aws_region` |


---

## 📁 Terraform Folder Structure Best Practices

Every day from Day 03 onwards follows this exact structure — the same structure used in real production projects.

### Why Split Into Multiple Files?

Think of it like a restaurant kitchen:
- **main.tf** = the actual cooking (resources being created)
- **provider.tf** = which kitchen equipment to use (AWS, Azure, GCP)
- **variables.tf** = the ingredient list with options (inputs)
- **outputs.tf** = what gets plated and served (values you share)
- **README.md** = the recipe card (documentation)

Keeping everything in one file works for 10 lines. At 500 lines, you'll spend more time searching than building.

### The Exact Structure

```
DayXX/
├── code/
│   ├── provider.tf        # terraform{} block + provider configs
│   ├── variables.tf       # all variable blocks
│   ├── main.tf            # resources + data sources + locals
│   ├── outputs.tf         # all output blocks
│   └── terraform.tfvars   # actual values (never commit real secrets)
└── theory.md              # concepts + real-life examples
```

### File-by-File Rules

#### `provider.tf`
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = var.aws_region }
```
- Always put the `terraform {}` block here
- One provider block per cloud
- Use `alias` for multi-region setups

#### `variables.tf`
```hcl
variable "environment" {
  description = "Which environment: dev / staging / prod"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev","staging","prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}
```
- Every variable **must** have a `description`
- Use `validation` blocks to catch bad input early
- Sensitive variables: add `sensitive = true`

#### `main.tf`
```hcl
locals { name_prefix = "${var.project}-${var.environment}" }

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${local.name_prefix}-vpc" }
}
```
- Put `locals {}` at the top of main.tf
- Group related resources together with comments
- Reference variables as `var.x`, locals as `local.x`

#### `outputs.tf`
```hcl
output "vpc_id" {
  description = "The VPC ID — pass this to EKS, RDS modules"
  value       = aws_vpc.main.id
}
```
- Every output **must** have a `description`
- Outputs are how modules talk to each other
- Add `sensitive = true` for passwords, keys

#### `terraform.tfvars`
```hcl
aws_region  = "us-east-1"
environment = "dev"
project     = "myapp"
```
- Real values go here
- Add to `.gitignore` if it contains secrets
- Create `terraform.tfvars.example` to show team the shape

### What Goes Where — Quick Reference

| Code | File |
|---|---|
| `terraform {}` block | `provider.tf` |
| `provider "aws" {}` | `provider.tf` |
| `variable "x" {}` | `variables.tf` |
| `locals {}` | `main.tf` |
| `data "aws_vpc" {}` | `main.tf` |
| `resource "aws_vpc" {}` | `main.tf` |
| `output "vpc_id" {}` | `outputs.tf` |
| Actual values | `terraform.tfvars` |

### .gitignore for Every Terraform Project
```
.terraform/
.terraform.lock.hcl     # commit this — it pins provider versions
terraform.tfstate
terraform.tfstate.backup
*.tfvars                 # comment out if no secrets inside
!terraform.tfvars.example
crash.log
override.tf
```

### Commands Cheatsheet
```bash
terraform fmt           # auto-format all .tf files
terraform validate      # check syntax without AWS calls
terraform init          # download providers (re-run after provider.tf changes)
terraform plan          # preview changes
terraform apply         # apply (always review plan first)
terraform destroy       # tear down all resources
terraform output        # print outputs after apply
terraform state list    # see what Terraform is tracking
```
