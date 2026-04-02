output "vpc_id"       { description = "VPC ID — validated by Terratest"; value = aws_vpc.testable.id }
output "vpc_cidr"     { description = "VPC CIDR — Terratest checks this matches input"; value = aws_vpc.testable.cidr_block }
output "subnet_ids"   { description = "Subnet IDs — Terratest checks count = 2"; value = aws_subnet.public[*].id }
output "subnet_count" { description = "Number of subnets created"; value = length(aws_subnet.public) }
