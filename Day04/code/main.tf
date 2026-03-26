################################################################################
# Day 04 — Lifecycle Commands Demo
# Creates resources to safely practice init/plan/apply/destroy
################################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "learning"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name      = "day04-vpc"
    Day       = "Day04"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "day04-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "day04-subnet-b" }
}

output "vpc_id"      { value = aws_vpc.main.id }
output "subnet_a_id" { value = aws_subnet.a.id }
output "subnet_b_id" { value = aws_subnet.b.id }
