terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # In a real project add backend "s3" { ... } here
}
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { ManagedBy = "Terraform", Project = var.project, Day = "Day12",
             Workspace = terraform.workspace }
  }
}
