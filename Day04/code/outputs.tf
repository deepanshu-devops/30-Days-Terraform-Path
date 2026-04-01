################################################################################
# Day 04 — outputs.tf
################################################################################
output "vpc_id" {
  description = "VPC ID — pass to other modules that need a network"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "List of subnet IDs for multi-AZ deployments"
  value       = [aws_subnet.az_a.id, aws_subnet.az_b.id]
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}
