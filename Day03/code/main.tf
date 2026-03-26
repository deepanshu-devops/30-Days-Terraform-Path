################################################################################
# Day 03 — Providers, Resources & State
# Demonstrates: Multi-provider, resource meta-arguments, state concepts
################################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Default AWS provider (us-east-1)
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { ManagedBy = "Terraform", Day = "Day03" }
  }
}

# Aliased provider for a second region
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
  default_tags {
    tags = { ManagedBy = "Terraform", Day = "Day03" }
  }
}

# ---------------------------------------------------------------------------
# Data Sources — read existing data without creating resources
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---------------------------------------------------------------------------
# Resources in us-east-1 (default provider)
# ---------------------------------------------------------------------------
resource "random_pet" "suffix" {
  length = 2
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "day03-vpc-${random_pet.suffix.id}" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id  # Implicit dependency
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "day03-public-subnet", Tier = "public" }
}

resource "aws_security_group" "web" {
  name        = "day03-web-sg"
  description = "Security group for web tier"
  vpc_id      = aws_vpc.main.id

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
    description = "All outbound traffic"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "day03-web-sg" }
}

# Resource with lifecycle rules
resource "aws_s3_bucket" "logs" {
  bucket        = "day03-logs-${random_pet.suffix.id}"
  force_destroy = true

  lifecycle {
    # Uncomment in production to prevent accidental deletion:
    # prevent_destroy = true
    ignore_changes = [
      tags["CreatedDate"] # Don't track this tag change in plan
    ]
  }

  tags = {
    Name        = "day03-logs"
    CreatedDate = "2024-01-01" # Will be ignored by lifecycle rule above
  }
}

# ---------------------------------------------------------------------------
# Resource in eu-west-1 (aliased provider)
# ---------------------------------------------------------------------------
resource "aws_vpc" "eu" {
  provider   = aws.eu_west
  cidr_block = "10.1.0.0/16"

  tags = { Name = "day03-vpc-eu-${random_pet.suffix.id}" }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "us_vpc_id" {
  description = "VPC ID in us-east-1"
  value       = aws_vpc.main.id
}

output "eu_vpc_id" {
  description = "VPC ID in eu-west-1"
  value       = aws_vpc.eu.id
}

output "aws_account_id" {
  description = "Current AWS account"
  value       = data.aws_caller_identity.current.account_id
}

output "latest_amazon_linux_ami" {
  description = "Latest Amazon Linux 2023 AMI"
  value       = data.aws_ami.amazon_linux.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}
