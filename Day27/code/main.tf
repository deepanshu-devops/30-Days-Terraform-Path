################################################################################
# Day 27 — Terraform Best Practices Reference Config
# Anti-patterns and their fixes demonstrated
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  # ✅ CORRECT: Remote state with locking
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "day27/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  # ✅ CORRECT: No credentials here — uses IAM role / environment
}

# ✅ CORRECT: for_each instead of count for stable addressing
variable "subnets" {
  type = map(object({ cidr = string, az = string }))
  default = {
    "private-1a" = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    "private-1b" = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "day27-best-practices", ManagedBy = "Terraform" }
}

resource "aws_subnet" "private" {
  for_each          = var.subnets  # ✅ for_each, not count
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = { Name = "day27-${each.key}", ManagedBy = "Terraform" }
}

# ✅ CORRECT: Sensitive output marked as sensitive
output "vpc_id" { value = aws_vpc.main.id }
output "subnet_ids" {
  value     = { for k, v in aws_subnet.private : k => v.id }
  sensitive = false
}
