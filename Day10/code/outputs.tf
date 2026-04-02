# Root module exposes module outputs — consumers don't need to know module internals
output "vpc_id"             { description = "VPC ID from vpc module";           value = module.vpc.vpc_id }
output "public_subnet_ids"  { description = "Public subnet IDs";               value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { description = "Private subnet IDs";              value = module.vpc.private_subnet_ids }
