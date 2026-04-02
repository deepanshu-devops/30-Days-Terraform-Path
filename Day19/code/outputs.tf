output "vpc_id" { value = aws_vpc.main.id }
output "sg_id" { value = aws_security_group.web.id }
output "bucket_name" { value = aws_s3_bucket.secure.bucket }
