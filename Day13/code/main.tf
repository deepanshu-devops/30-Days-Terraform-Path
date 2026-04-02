################################################################################
# Day 13 — main.tf
# Topic: count, for_each & Dynamic Blocks
#
# Real-life scenario:
#   You need 4 subnets across 2 AZs. With count you could do it,
#   but if you remove the first subnet, all others get destroyed.
#   for_each uses stable keys — removing one key only removes that subnet.
################################################################################
locals { name_prefix = "${var.project}-${var.environment}" }

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true; enable_dns_hostnames = true
  tags = { Name = "${local.name_prefix}-vpc" }
}

# ── for_each on a map — STABLE keys ──────────────────────────────────────────
# Removing "public-1a" from the map ONLY destroys that subnet.
# With count, removing index 0 would destroy ALL subnets and recreate.
resource "aws_subnet" "main" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name      = "${local.name_prefix}-${each.key}"
    Tier      = each.value.tier
    ManagedBy = "Terraform"
  }
}

# ── dynamic block — variable number of ingress rules ─────────────────────────
# Instead of hardcoding 5 separate ingress blocks, loop over a variable
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Web tier — rules defined in variables"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [ingress.value.cidr]
      description = ingress.value.description
    }
  }

  egress {
    from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  tags = { Name = "${local.name_prefix}-web-sg" }
}
