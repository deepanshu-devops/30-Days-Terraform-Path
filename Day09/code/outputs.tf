output "vpc_id"           { description = "VPC ID"; value = aws_vpc.main.id }
output "subnet_id"        { description = "Primary subnet ID"; value = aws_subnet.primary.id }
output "critical_bucket"  { description = "Critical data bucket (prevent_destroy enabled)"; value = aws_s3_bucket.critical_data.bucket }
