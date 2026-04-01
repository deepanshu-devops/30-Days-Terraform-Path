################################################################################
# Day 04 — main.tf
# Topic: Terraform Lifecycle
#
# Real-life scenario:
#   A developer asks you: "Can you spin up a test environment for the QA team?"
#   You run: init → plan → apply. QA finishes. You run: destroy.
#   Total time: 5 minutes. Total console clicks: 0.
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# VPC — the network container for everything else
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

# Two subnets in different AZs — required for load balancers and RDS
resource "aws_subnet" "az_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${local.name_prefix}-subnet-a", AZ = "${var.aws_region}a" }
}

resource "aws_subnet" "az_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${local.name_prefix}-subnet-b", AZ = "${var.aws_region}b" }
}

# Internet gateway — allows public internet access from the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}
