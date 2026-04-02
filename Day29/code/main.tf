################################################################################
# Day29 — main.tf
# Topic: Learning Resources
################################################################################

# Day 29 — Learning Resources reference config
# Demonstrates LocalStack for cost-free local practice

locals { name_prefix = "${var.project}-local" }

resource "aws_vpc" "practice" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${local.name_prefix}-vpc", Purpose = "learning" }
}
resource "aws_s3_bucket" "practice" {
  bucket        = "${local.name_prefix}-bucket"
  force_destroy = true
  tags          = { Name = "${local.name_prefix}-bucket" }
}
