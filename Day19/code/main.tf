################################################################################
# Day19 — main.tf
# Topic: Security Scanning: Checkov & tfsec
# Real-life: Security Scanning: A developer creates an RDS instance with publicly_accessible = true. Without scanning: it goes to prod. With Checkov in CI/CD: the PR is blocked with CKV_AWS_17. The database is never exposed to the internet.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}
# Security group following ALL Checkov/tfsec rules
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Web tier — HTTPS only inbound"   # description is required (CKV_AWS_23)
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443; to_port = 443; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS from internet"
  }
  # Port 22 is NOT open — SSH access via SSM Session Manager instead
  egress {
    from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  tags = { Name = "${local.name_prefix}-web-sg" }
}
resource "aws_s3_bucket" "secure" {
  bucket        = "${local.name_prefix}-secure-data"
  force_destroy = true
  tags          = { Name = "${local.name_prefix}-secure", Environment = var.environment }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule   { apply_server_side_encryption_by_default { sse_algorithm = "AES256" }; bucket_key_enabled = true }
}
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  versioning_configuration { status = "Enabled" }
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
