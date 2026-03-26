################################################################################
# Day 12 — Environment Management Patterns
# Pattern 1: Workspaces
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "workspace-demo/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" { region = "us-east-1" }

# Workspace-based configuration
locals {
  env_config = {
    default = { instance_type = "t3.micro",  subnet_count = 1, nat_gateway = false }
    dev     = { instance_type = "t3.micro",  subnet_count = 2, nat_gateway = false }
    staging = { instance_type = "t3.small",  subnet_count = 2, nat_gateway = true }
    prod    = { instance_type = "t3.medium", subnet_count = 3, nat_gateway = true }
  }

  config = lookup(local.env_config, terraform.workspace, local.env_config["default"])

  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
    Day         = "Day12"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = merge(local.common_tags, { Name = "day12-${terraform.workspace}-vpc" })
}

output "workspace"     { value = terraform.workspace }
output "instance_type" { value = local.config.instance_type }
output "vpc_id"        { value = aws_vpc.main.id }
