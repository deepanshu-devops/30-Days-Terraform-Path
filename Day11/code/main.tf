################################################################################
# Day 11 — main.tf
# Topic: Module Versioning Best Practices
#
# Real-life scenario:
#   A colleague "improved" a shared module and pushed to main branch.
#   Three prod environments broke simultaneously because they all pointed
#   to the same unversioned module source.
#   Version pinning would have prevented this entirely.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }

# ── Community module pinned to exact version ──────────────────────────────────
# GOOD: version = "5.5.3"  — exact, deterministic, safe
# BAD:  version = "~> 5"   — in production (might auto-upgrade)
# NEVER: no version at all — newest version always loaded
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"   # Pinned to exact patch version

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs            = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets= ["10.0.1.0/24",   "10.0.2.0/24"]

  enable_nat_gateway = false   # Disabled to save cost in learning
  enable_dns_hostnames = true

  tags = { Environment = var.environment, ManagedBy = "Terraform" }
}
