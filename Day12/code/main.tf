################################################################################
# Day 12 — main.tf
# Topic: Workspaces vs tfvars for Environment Management
#
# Real-life scenario:
#   You need dev, staging, and prod environments. Do you use workspaces
#   or separate tfvars files? This config demonstrates BOTH patterns
#   and explains when to use each.
################################################################################

locals {
  # terraform.workspace = "default" | "dev" | "staging" | "prod"
  name_prefix = "${var.project}-${terraform.workspace}"

  # Workspace-driven configuration: different infra per workspace
  workspace_config = {
    default = { subnet_count = 1, enable_nat = false }
    dev     = { subnet_count = 1, enable_nat = false }
    staging = { subnet_count = 2, enable_nat = false }
    prod    = { subnet_count = 3, enable_nat = true  }
  }

  config = lookup(local.workspace_config, terraform.workspace, local.workspace_config["default"])
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${local.name_prefix}-vpc"
    Workspace = terraform.workspace
  }
}

output "current_workspace" { value = terraform.workspace }
output "vpc_id"            { value = aws_vpc.main.id }
output "workspace_config"  { value = local.config }
