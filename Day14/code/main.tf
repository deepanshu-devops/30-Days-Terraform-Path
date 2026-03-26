################################################################################
# Day 14 — Terraform Import Examples
# Shows both old import command and new import blocks (Terraform 1.5+)
################################################################################
terraform {
  required_version = ">= 1.5.0"  # Required for import blocks
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# ─────────────────────────────────────────────────────────────────
# NEW WAY: Import blocks (Terraform 1.5+)
# Replace the ID with your actual resource ID before applying
# ─────────────────────────────────────────────────────────────────

# Uncomment and replace ID to import an existing VPC:
# import {
#   id = "vpc-0abc123456789"   # Replace with your VPC ID
#   to = aws_vpc.imported
# }

# Uncomment and replace ID to import an existing security group:
# import {
#   id = "sg-0abc123456789"    # Replace with your SG ID
#   to = aws_security_group.imported
# }

# ─────────────────────────────────────────────────────────────────
# Resource blocks for imported resources
# Either write these manually, or use:
#   terraform plan -generate-config-out=generated.tf
# ─────────────────────────────────────────────────────────────────

# Example: imported VPC (fill in actual attributes from your VPC)
resource "aws_vpc" "imported" {
  cidr_block           = "10.0.0.0/16"   # Must match real VPC
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "my-existing-vpc", ManagedBy = "Terraform" }
}

# After import + apply: terraform plan should show "No changes"
output "imported_vpc_id" { value = aws_vpc.imported.id }
