################################################################################
# Day 03 — outputs.tf
# Outputs are values Terraform prints after apply.
# Other modules or scripts can read these — e.g., pass vpc_id into an EKS module
################################################################################

output "us_vpc_id" {
  description = "US VPC ID — pass this to EKS, RDS, ALB modules"
  value       = aws_vpc.us.id
}

output "eu_vpc_id" {
  description = "EU VPC ID — used for GDPR-compliant EU workloads"
  value       = aws_vpc.eu.id
}

output "public_subnet_id" {
  description = "Public subnet ID in the US VPC"
  value       = aws_subnet.public.id
}

output "web_sg_id" {
  description = "Web-tier security group ID"
  value       = aws_security_group.web.id
}

output "logs_bucket_name" {
  description = "S3 bucket for application logs"
  value       = aws_s3_bucket.logs.bucket
}

output "aws_account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "latest_ami_id" {
  description = "Latest Amazon Linux 2023 AMI in the region"
  value       = data.aws_ami.amazon_linux.id
}

output "available_azs" {
  description = "Availability zones in the primary region"
  value       = data.aws_availability_zones.available.names
}
