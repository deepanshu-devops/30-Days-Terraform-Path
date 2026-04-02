output "vpc_id"        { description = "VPC ID"; value = aws_vpc.main.id }
output "subnet_ids"    { description = "Map of subnet name -> ID"; value = { for k, v in aws_subnet.main : k => v.id } }
output "public_subnet_ids"  { description = "Only public subnets"; value = [for k, v in aws_subnet.main : v.id if v.tags["Tier"] == "public"] }
output "private_subnet_ids" { description = "Only private subnets"; value = [for k, v in aws_subnet.main : v.id if v.tags["Tier"] == "private"] }
output "sg_id"         { description = "Web security group ID"; value = aws_security_group.web.id }
