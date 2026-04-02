variable "name"                 { description = "Name prefix"; type = string }
variable "vpc_cidr"             { description = "VPC CIDR block"; type = string }
variable "environment"          { description = "Environment name"; type = string }
variable "availability_zones"   { description = "AZs for subnets"; type = list(string) }
variable "public_subnet_cidrs"  { description = "CIDRs for public subnets"; type = list(string); default = [] }
variable "private_subnet_cidrs" { description = "CIDRs for private subnets"; type = list(string); default = [] }
variable "enable_nat_gateway"   { description = "Create NAT Gateway"; type = bool; default = false }
variable "tags"                 { description = "Extra tags"; type = map(string); default = {} }
