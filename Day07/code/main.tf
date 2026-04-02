################################################################################
# Day 07 — main.tf
# Topic: HCL Functions & Expressions
#
# Real-life scenario:
#   You need to provision subnets across all AZs in a region — but you
#   don't know how many AZs exist (it varies by region). Functions let you
#   compute CIDRs and iterate dynamically rather than hardcoding.
################################################################################

locals {
  # ── String functions ────────────────────────────────────────────────────
  name_prefix    = lower(replace("${var.project}-${var.environment}", "_", "-"))
  project_upper  = upper(var.project)
  padded_name    = format("%-20s", var.project)   # left-align, 20 chars

  # ── Collection functions ─────────────────────────────────────────────────
  sorted_envs    = sort(var.env_list)                    # ["dev","prod","staging"]
  unique_envs    = distinct(concat(var.env_list, ["dev"])) # dedup
  env_count      = length(var.env_list)

  # ── Network functions ────────────────────────────────────────────────────
  # Automatically compute /24 subnets from a /16 VPC
  # cidrsubnet("10.0.0.0/16", 8, 1) → "10.0.1.0/24"
  subnet_cidrs   = [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]

  # ── For expressions — transform collections ───────────────────────────
  env_upper_list = [for e in var.env_list : upper(e)]            # ["DEV","STAGING","PROD"]
  non_prod_envs  = [for e in var.env_list : e if e != "prod"]    # filter
  resource_names = [for k, v in var.resource_map : "${k}-${v}"]  # map iteration
  instance_map   = {for k, v in var.resource_map : k => v}       # map → map

  # ── Conditional expression ───────────────────────────────────────────────
  is_production  = var.environment == "prod"
  instance_type  = local.is_production ? "t3.large" : "t3.micro"
  log_retention  = local.is_production ? 90 : 7  # days

  # ── Merge function for tags ──────────────────────────────────────────────
  common_tags = merge(
    { Project = var.project, Environment = var.environment },
    local.is_production ? { CriticalLevel = "high", BackupRequired = "true" } : {}
  )
}

data "aws_availability_zones" "available" { state = "available" }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

# Create subnets using computed CIDRs — no hardcoding
resource "aws_subnet" "public" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-subnet-${count.index + 1}"
    CIDR = local.subnet_cidrs[count.index]
  })
}
