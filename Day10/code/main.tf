################################################################################
# Day 10 — main.tf
# Topic: Reusable Terraform Modules
#
# Real-life scenario:
#   Before modules: VPC code copy-pasted into 12 projects. Fixing one bug
#   requires 12 PRs. With a module: fix once, all 12 projects benefit.
#
# This config calls a local VPC module.
# The module is in: ./modules/vpc/
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Call the VPC module ───────────────────────────────────────────────────────
# The module is a folder with its own main.tf, variables.tf, outputs.tf
module "vpc" {
  source = "./modules/vpc"   # Local path — in production use a Git tag

  # Inputs — must match the module's variable definitions
  name               = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  environment        = var.environment
  enable_nat_gateway = var.enable_nat_gateway

  # Subnet CIDRs passed in — module doesn't decide for you
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
}
