################################################################################
# Day 15 — main.tf
# Topic: Terraform in CI/CD (GitHub Actions + Jenkins)
#
# Real-life scenario:
#   An engineer runs terraform apply directly on prod from their laptop.
#   They accidentally apply a stale plan. Two EC2 instances are replaced.
#   Service is down for 20 minutes.
#
#   Solution: Nobody applies from laptops. The pipeline applies.
#   plan runs on PR → human reviews → merge → pipeline applies.
################################################################################
locals { name_prefix = "${var.project}-${var.environment}" }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc", Pipeline = "github-actions" }
}
