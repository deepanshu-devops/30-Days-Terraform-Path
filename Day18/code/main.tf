################################################################################
# Day18 — main.tf
# Topic: Policy as Code: Sentinel & OPA
# Real-life: Policy as Code: Your security team has a rule: no S3 bucket may be unencrypted. Without policy enforcement, developers forget. With OPA/Sentinel: the pipeline blocks any PR that tries to create an unencrypted bucket — before it ever reaches AWS.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${local.name_prefix}-vpc", Environment = var.environment }
}
# Compliant S3 bucket — will PASS OPA/Checkov policies
resource "aws_s3_bucket" "compliant" {
  bucket        = "${local.name_prefix}-compliant-${var.environment}"
  force_destroy = true
  tags          = { Name = "${local.name_prefix}-data", Environment = var.environment, Owner = "platform-team" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "compliant" {
  bucket = aws_s3_bucket.compliant.id
  rule   { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_public_access_block" "compliant" {
  bucket = aws_s3_bucket.compliant.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "compliant" {
  bucket = aws_s3_bucket.compliant.id
  versioning_configuration { status = "Enabled" }
}
