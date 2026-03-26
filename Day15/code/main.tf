# Day 15 — CI/CD Files
# See implementation.md for GitHub Actions workflow
# This file shows the Terraform config structure for CI/CD testing

################################################################################
# Day 15 — Terraform Config with CI/CD Best Practices
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # Backend config — required for CI/CD
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "day15/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  # CI/CD: credentials come from OIDC role assumption
  # No hardcoded credentials ever
}

variable "aws_region"  { type = string; default = "us-east-1" }
variable "environment" { type = string; default = "dev" }

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "day15-cicd-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Pipeline    = "GitHub-Actions"
  }
}

output "vpc_id" { value = aws_vpc.main.id }
