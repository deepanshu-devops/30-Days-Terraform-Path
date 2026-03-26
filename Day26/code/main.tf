################################################################################
# Day 26 — Infracost Demo: Resources with Known Monthly Costs
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

variable "environment"  { type = string; default = "dev" }
variable "project"      { type = string; default = "day26" }

# These resources have known monthly costs that Infracost can estimate:
# Run: infracost breakdown --path . to see estimated costs

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"  # VPC itself: FREE
  tags = { Name = "day26-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "day26-public-subnet" }
}

resource "aws_eip" "nat" {
  domain = "vpc"  # EIP: ~$3.65/month if unattached
}

# NAT Gateway: ~$32.40/month + data transfer costs
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "day26-nat" }
}

# S3 bucket: Storage costs vary by usage (Infracost shows base cost)
resource "aws_s3_bucket" "data" {
  bucket        = "day26-cost-demo-bucket"
  force_destroy = true
  tags          = { Name = "day26-data" }
}

output "vpc_id"         { value = aws_vpc.main.id }
output "nat_gateway_id" { value = aws_nat_gateway.main.id }

# After apply, run:
# infracost breakdown --path .
# Expected: ~$35/month (NAT Gateway + EIP)
