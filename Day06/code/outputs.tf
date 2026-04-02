output "account_id"      { description = "AWS account ID";            value = data.aws_caller_identity.current.account_id }
output "current_region"  { description = "Current AWS region";        value = data.aws_region.current.name }
output "available_azs"   { description = "Available AZs in region";   value = data.aws_availability_zones.available.names }
output "latest_ami"      { description = "Latest Amazon Linux 2023 AMI"; value = data.aws_ami.amazon_linux.id }
output "vpc_id"          { description = "VPC ID";                    value = aws_vpc.main.id }
output "subnet_id"       { description = "Public subnet ID";          value = aws_subnet.public.id }
output "ec2_role_arn"    { description = "EC2 IAM role ARN";          value = aws_iam_role.ec2_role.arn }
