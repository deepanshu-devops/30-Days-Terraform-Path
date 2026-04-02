output "vpc_id" { value = aws_vpc.main.id }
output "account_id" { value = data.aws_caller_identity.current.account_id }
output "subnet_ids" { value = { for k, v in aws_subnet.main : k => v.id } }
