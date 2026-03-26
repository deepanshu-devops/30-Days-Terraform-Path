################################################################################
# Day 18 — Policy Targets: configs that policies should scan
# Run conftest against the plan output of this config
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# ── COMPLIANT: This S3 bucket will PASS the encryption policy ─────────────
resource "aws_s3_bucket" "compliant" {
  bucket        = "day18-compliant-bucket-demo"
  force_destroy = true
  tags = { Environment = "learning", Owner = "platform-team", Project = "day18" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliant" {
  bucket = aws_s3_bucket.compliant.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "compliant" {
  bucket                  = aws_s3_bucket.compliant.id
  block_public_acls       = true; block_public_policy     = true
  ignore_public_acls      = true; restrict_public_buckets = true
}

# ── COMPLIANT: VPC with required tags ─────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Environment = "learning"
    Owner       = "platform-team"
    Project     = "day18"
    ManagedBy   = "Terraform"
  }
}

output "compliant_bucket" { value = aws_s3_bucket.compliant.bucket }
output "vpc_id"           { value = aws_vpc.main.id }
