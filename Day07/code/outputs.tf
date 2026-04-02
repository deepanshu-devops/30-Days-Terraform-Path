output "vpc_id"           { description = "VPC ID";                         value = aws_vpc.main.id }
output "subnet_cidrs"     { description = "Computed subnet CIDRs";          value = local.subnet_cidrs }
output "subnet_ids"       { description = "Created subnet IDs";             value = aws_subnet.public[*].id }
output "name_prefix"      { description = "Computed name prefix";           value = local.name_prefix }
output "env_upper_list"   { description = "Uppercased env list";            value = local.env_upper_list }
output "non_prod_envs"    { description = "All envs except prod";           value = local.non_prod_envs }
output "instance_type"    { description = "Selected instance type";         value = local.instance_type }
output "common_tags"      { description = "Merged common tags";             value = local.common_tags }
