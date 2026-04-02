################################################################################
# Day 05 — main.tf
# Topic: Variables, Outputs & Locals
#
# Real-life scenario:
#   Your team manages dev, staging, and prod with the SAME Terraform code.
#   Only the .tfvars file changes per environment.
#   Locals compute values once so you never repeat yourself.
################################################################################

locals {
  # Computed once, used everywhere — no copy-pasting
  name_prefix = "${var.project}-${var.environment}"

  # Conditional logic: prod gets bigger, dev stays cheap
  nat_count      = var.enable_nat_gateway ? 1 : 0
  instance_class = var.environment == "prod" ? "db.r6g.large" : "db.t3.micro"

  # Merge default tags + user-supplied tags
  # User tags win if there's a conflict (merge keeps last key)
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner_email
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  # Compute one CIDR per subnet from the VPC CIDR
  subnet_cidrs = [
    for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
}

data "aws_availability_zones" "available" { state = "available" }

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

# ── Public Subnets (one per subnet_count) ────────────────────────────────────
resource "aws_subnet" "public" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}
