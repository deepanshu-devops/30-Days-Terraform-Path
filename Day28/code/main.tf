################################################################################
# Day 28 — Interview Prep: Config Demonstrating All Key Concepts
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# ── Variables (inputs) ────────────────────────────────────────────────────
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ── Locals (computed) ─────────────────────────────────────────────────────
locals {
  is_prod     = var.environment == "prod"
  name_prefix = "interview-demo-${var.environment}"
  common_tags = { Environment = var.environment, ManagedBy = "Terraform", Day = "Day28" }
}

# ── Data source ───────────────────────────────────────────────────────────
data "aws_availability_zones" "available" { state = "available" }

# ── Resources with for_each ───────────────────────────────────────────────
variable "subnets" {
  type = map(object({ cidr = string, tier = string }))
  default = {
    "public-a"  = { cidr = "10.0.1.0/24",  tier = "public" }
    "private-a" = { cidr = "10.0.11.0/24", tier = "private" }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "main" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}", Tier = each.value.tier })
}

# ── Conditional resource ───────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  count  = local.is_prod ? 0 : 1  # skip IGW in prod (handled by transit gateway)
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

# ── Outputs ───────────────────────────────────────────────────────────────
output "vpc_id"      { value = aws_vpc.main.id }
output "subnet_ids"  { value = { for k, v in aws_subnet.main : k => v.id } }
output "environment" { value = var.environment }
output "is_prod"     { value = local.is_prod }
