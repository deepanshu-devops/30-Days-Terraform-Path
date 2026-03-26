################################################################################
# Day 08 — Bootstrap: S3 State + DynamoDB Lock
# Run this ONCE to create the backend infrastructure
# After apply, migrate your other configs to use this backend
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # NO backend block here — bootstrap uses local state
}

provider "aws" { region = var.aws_region }

variable "aws_region"        { type = string; default = "us-east-1" }
variable "state_bucket_name" { type = string; default = "my-org-terraform-state" }
variable "lock_table_name"   { type = string; default = "terraform-state-lock" }

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
  lifecycle { prevent_destroy = true }
  tags = { Name = "Terraform State", ManagedBy = "Terraform", Purpose = "terraform-state" }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state.id
  target_prefix = "access-logs/"
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute { name = "LockID"; type = "S" }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
  lifecycle { prevent_destroy = true }
  tags = { Name = "Terraform State Lock", ManagedBy = "Terraform" }
}

output "state_bucket_name"  { value = aws_s3_bucket.terraform_state.bucket }
output "state_bucket_arn"   { value = aws_s3_bucket.terraform_state.arn }
output "lock_table_name"    { value = aws_dynamodb_table.terraform_lock.name }
output "backend_config" {
  value = <<-EOT
    Add this to your terraform {} block:
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.bucket}"
      key            = "<project>/<env>/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
      encrypt        = true
    }
  EOT
}
