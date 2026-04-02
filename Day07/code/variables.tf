variable "aws_region"    { description = "AWS region"; type = string; default = "us-east-1" }
variable "project"       { description = "Project name"; type = string; default = "day07" }
variable "environment"   { description = "dev|staging|prod"; type = string; default = "dev" }
variable "vpc_cidr"      { description = "VPC CIDR block"; type = string; default = "10.0.0.0/16" }
variable "subnet_count"  { description = "Number of subnets to create"; type = number; default = 3 }
variable "env_list"      { description = "All environments"; type = list(string); default = ["dev","staging","prod"] }
variable "resource_map"  {
  description = "Map of resource names to their config"
  type        = map(string)
  default     = { "web" = "t3.micro", "api" = "t3.small", "worker" = "t3.medium" }
}
