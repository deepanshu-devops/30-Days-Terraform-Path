################################################################################
# Day20 — main.tf
# Topic: Terraform Testing with Terratest
# Real-life: Testing: You update a shared VPC module and tag a new version v1.3.0. Before tagging, a Terratest job runs: deploys the module in a real AWS account, checks that all outputs exist and are non-empty, validates the VPC CIDR matches input, then destroys everything. If any check fails — the release is blocked.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
resource "aws_vpc" "testable" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc", TestTarget = "true" }
}
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.testable.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  tags              = { Name = "${local.name_prefix}-public-${count.index + 1}" }
}
