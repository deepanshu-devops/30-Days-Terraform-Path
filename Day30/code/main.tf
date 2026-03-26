################################################################################
# Day 30 — Complete Infrastructure Template
# Summary of everything learned in 30 days
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }

  # Day 08: Remote state
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "day30/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  # Day 17: No credentials here — uses IAM role / OIDC
  default_tags { tags = local.common_tags }
}

# Day 05: Variables with validation
variable "aws_region"  { type = string; default = "us-east-1" }
variable "project"     { type = string; default = "final-project" }
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}
variable "subnet_config" {
  type = map(object({ cidr = string, az = string, tier = string }))
  default = {
    "public-a"  = { cidr = "10.0.1.0/24",  az = "us-east-1a", tier = "public" }
    "public-b"  = { cidr = "10.0.2.0/24",  az = "us-east-1b", tier = "public" }
    "private-a" = { cidr = "10.0.11.0/24", az = "us-east-1a", tier = "private" }
    "private-b" = { cidr = "10.0.12.0/24", az = "us-east-1b", tier = "private" }
  }
}

# Day 05: Locals
locals {
  name_prefix  = "${var.project}-${var.environment}"
  is_prod      = var.environment == "prod"
  common_tags  = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Day         = "Day30-Summary"
  }
}

# Day 06: Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Day 03: Resources
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

# Day 13: for_each
resource "aws_subnet" "main" {
  for_each          = var.subnet_config
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "${local.name_prefix}-${each.key}", Tier = each.value.tier }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# Day 19: Security-compliant S3 bucket
resource "aws_s3_bucket" "app_data" {
  bucket        = "${local.name_prefix}-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = !local.is_prod
  tags          = { Name = "${local.name_prefix}-data" }
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}

# Day 05: Outputs
output "vpc_id"      { value = aws_vpc.main.id }
output "subnet_ids"  { value = { for k, v in aws_subnet.main : k => v.id } }
output "bucket_name" { value = aws_s3_bucket.app_data.bucket }
output "account_id"  { value = data.aws_caller_identity.current.account_id }
output "region"      { value = data.aws_region.current.name }
output "environment" { value = var.environment }
output "is_prod"     { value = local.is_prod }
