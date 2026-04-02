################################################################################
# Day 06 — main.tf
# Topic: Data Sources & Resource Dependencies
#
# Real-life scenario:
#   You join a team that has existing infrastructure. You don't own the VPC —
#   another team does. But you need to put your resources inside it.
#   Data sources let you reference infra you didn't create.
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Data Sources ─────────────────────────────────────────────────────────────
# Read: your AWS account ID and region at runtime
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Read: available AZs — never hardcode AZ names
data "aws_availability_zones" "available" { state = "available" }

# Read: latest Amazon Linux 2023 AMI — never hardcode AMI IDs (they change!)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name";                values = ["al2023-ami-*-x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
  filter { name = "state";               values = ["available"] }
}

# Build an IAM policy document without writing raw JSON
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ── Resources that USE data source values ────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  # Use data source — don't hardcode "us-east-1a"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${local.name_prefix}-public-1" }
}

# IAM role using the policy document data source
resource "aws_iam_role" "ec2_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
