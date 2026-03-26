# Day 29 — Learning Resources Reference
# This file contains LocalStack config for free local development

################################################################################
# LocalStack provider config — run AWS locally for free
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# LocalStack configuration (no real AWS account needed)
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = "http://localhost:4566"
    ec2      = "http://localhost:4566"
    iam      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    sts      = "http://localhost:4566"
  }
}

# Practice resource — works with LocalStack
resource "aws_vpc" "practice" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "localstack-practice-vpc", Environment = "local" }
}

resource "aws_s3_bucket" "practice" {
  bucket        = "localstack-practice-bucket"
  force_destroy = true
  tags          = { Name = "localstack-practice", Environment = "local" }
}

output "vpc_id"     { value = aws_vpc.practice.id }
output "bucket_name" { value = aws_s3_bucket.practice.bucket }

# To use:
# docker run --rm -p 4566:4566 localstack/localstack
# terraform init && terraform apply -auto-approve
