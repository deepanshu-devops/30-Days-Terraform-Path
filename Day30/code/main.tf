################################################################################
# Day30 — main.tf
# Topic: Series Recap & What's Next
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform", Day = "Day30-Summary" }
}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }
variable "subnets" {
  type = map(object({ cidr = string; az = string; tier = string }))
  default = {
    "public-a"  = { cidr = "10.0.1.0/24",  az = "us-east-1a", tier = "public" }
    "private-a" = { cidr = "10.0.11.0/24", az = "us-east-1a", tier = "private" }
  }
}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr; enable_dns_support = true; enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}
resource "aws_subnet" "main" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}", Tier = each.value.tier })
}
resource "aws_s3_bucket" "data" {
  bucket        = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "prod"
  lifecycle { prevent_destroy = false }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-data" })
}
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule   { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}
