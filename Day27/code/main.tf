################################################################################
# Day27 — main.tf
# Topic: Top 5 Terraform Mistakes
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
# This config applies all 5 lessons from the mistakes chapter.
# Notice: remote backend, for_each not count, prevent_destroy, no secrets in code.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = { Name = "${local.name_prefix}-vpc", ManagedBy = "Terraform" }
}
variable "subnets" {
  type = map(object({ cidr = string, az = string }))
  default = {
    "private-a" = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    "private-b" = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  }
}
resource "aws_subnet" "main" {
  for_each          = var.subnets   # Lesson 6: for_each not count
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "${local.name_prefix}-${each.key}" }
}
resource "aws_s3_bucket" "data" {
  bucket        = "${local.name_prefix}-data"
  force_destroy = false
  lifecycle { prevent_destroy = true }   # Lesson 7: deletion protection
  tags = { Name = "${local.name_prefix}-data" }
}
