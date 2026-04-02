################################################################################
# Day 08 — main.tf
# Topic: Remote State with S3 + DynamoDB Locking
#
# Real-life scenario:
#   Your team has 5 engineers. Two of them run terraform apply at the same time.
#   Without remote state + locking: state corruption, 4-hour incident.
#   With S3 + DynamoDB: second apply waits, no corruption, no incident.
#   This config creates the backend infrastructure. Run it once.
################################################################################

# ── S3 Bucket for Terraform State ────────────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # CRITICAL: Never accidentally delete the state bucket
  lifecycle { prevent_destroy = true }

  tags = { Name = "Terraform State", Purpose = "terraform-state" }
}

# Enable versioning — roll back to previous state if corruption occurs
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

# Encrypt state at rest — state can contain secrets (passwords, keys)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

# Block all public access — state files must never be public
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging — audit who read/wrote the state
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state.id
  target_prefix = "state-access-logs/"
}

# ── DynamoDB Table for State Locking ─────────────────────────────────────────
resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"    # No capacity planning needed
  hash_key     = "LockID"             # Must be exactly "LockID" — Terraform requires this

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery on the lock table too
  point_in_time_recovery { enabled = true }
  server_side_encryption  { enabled = true }

  lifecycle { prevent_destroy = true }

  tags = { Name = "Terraform State Lock", Purpose = "terraform-lock" }
}
