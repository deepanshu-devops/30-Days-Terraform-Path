variable "aws_region"        { description = "AWS region for state bucket"; type = string; default = "us-east-1" }
variable "project"           { description = "Project name"; type = string; default = "day08" }
variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state (must be globally unique)"
  type        = string
  default     = "my-org-terraform-state-2024"
}
variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-lock"
}
