################################################################################
# Day 05 — outputs.tf
################################################################################

output "vpc_id" {
  description = "VPC ID — referenced by EKS, RDS, ALB modules"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "computed_name_prefix" {
  description = "The name prefix used for all resources (project-environment)"
  value       = local.name_prefix
}

output "common_tags" {
  description = "Tags applied to every resource in this configuration"
  value       = local.common_tags
}

# Sensitive output: shown as <sensitive> in plan, accessible via terraform output -raw
output "db_password_length" {
  description = "Length of the db password (sanity check without exposing value)"
  value       = length(var.db_password)
  sensitive   = false
}
