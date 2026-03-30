################################################################################
# Day 03 — main.tf
# Topic: Providers, Resources & State
#
# Real-life scenario:
#   You are a DevOps engineer at a startup. The product team asks you to
#   provision a basic network in both the US and EU for GDPR compliance.
#   Instead of clicking in two console sessions, you write this once.
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Data Sources (read-only queries — no resources created) ──────────────────

# Which AZs are available in our region?
data "aws_availability_zones" "available" {
  state = "available"
}

# Who is running this? Useful for building ARNs dynamically
data "aws_caller_identity" "current" {}

# Always get the latest Amazon Linux 2023 AMI — never hardcode AMI IDs
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── Random suffix so bucket names are globally unique ────────────────────────
resource "random_pet" "suffix" {
  length = 2
}

# ── US VPC (default provider = us-east-1) ───────────────────────────────────
# Real-life: Your US production network. Every other resource (EKS, RDS)
#            will live inside this VPC.
resource "aws_vpc" "us" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Required if you use private Route53 zones

  tags = {
    Name = "${local.name_prefix}-us-vpc"
    Tier = "networking"
  }
}

# Public subnet — web servers and load balancers go here
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.us.id            # Implicit dep: created after VPC
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${local.name_prefix}-public-subnet"
    Tier = "public"
  }
}

# Security group — only HTTPS in, all out
# Real-life: The firewall rules for your web tier
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Allow HTTPS inbound, all outbound"
  vpc_id      = aws_vpc.us.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  lifecycle {
    # Create the new SG before destroying the old one
    # Prevents downtime during security group updates
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-web-sg" }
}

# S3 bucket for application logs
resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name_prefix}-logs-${random_pet.suffix.id}"
  force_destroy = true # OK for learning; remove in prod

  lifecycle {
    # If someone adds a tag manually in console, Terraform won't fight them
    ignore_changes = [tags["LastModifiedByHuman"]]
  }

  tags = { Name = "${local.name_prefix}-logs" }
}

# ── EU VPC (aliased provider = eu-west-1) ───────────────────────────────────
# Real-life: GDPR requires EU customer data stays in EU.
#            Same pattern, different region, different CIDR.
resource "aws_vpc" "eu" {
  provider             = aws.eu_west         # Override to eu-west-1
  cidr_block           = var.eu_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name       = "${local.name_prefix}-eu-vpc"
    Compliance = "GDPR"
  }
}
