################################################################################
# Day 06 — Data Sources & Dependencies
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" { state = "available" }

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name"               values = ["al2023-ami-*-x86_64"] }
  filter { name = "virtualization-type" values = ["hvm"] }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}

# Resources using data sources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "day06-vpc" }
}

resource "aws_iam_role" "instance" {
  name               = "day06-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

output "account_id"        { value = data.aws_caller_identity.current.account_id }
output "region"            { value = data.aws_region.current.name }
output "latest_ami_id"     { value = data.aws_ami.amazon_linux_2023.id }
output "availability_zones" { value = data.aws_availability_zones.available.names }
