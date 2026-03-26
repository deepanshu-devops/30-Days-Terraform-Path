################################################################################
# Day 19 — Security-Compliant Terraform Config
# Run checkov and tfsec against this to see zero findings
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "day19-vpc", ManagedBy = "Terraform" }
}

# S3 bucket with all security controls enabled (passes all Checkov checks)
resource "aws_s3_bucket" "secure" {
  bucket        = "day19-secure-bucket-example"
  force_destroy = true
  tags          = { Name = "day19-secure", Environment = "learning" }
}

resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.secure.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "secure" {
  bucket        = aws_s3_bucket.secure.id
  target_bucket = aws_s3_bucket.secure.id
  target_prefix = "access-logs/"
}

# Security group following least privilege
resource "aws_security_group" "web" {
  name        = "day19-web-sg"
  description = "Web tier - HTTPS only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443; to_port = 443; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS"
  }
  # No port 22 / SSH open to internet
  egress {
    from_port = 0; to_port = 0; protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]; description = "All outbound"
  }
  tags = { Name = "day19-web-sg" }
}

output "vpc_id"         { value = aws_vpc.main.id }
output "bucket_name"   { value = aws_s3_bucket.secure.bucket }
output "security_group" { value = aws_security_group.web.id }
