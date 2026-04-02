terraform {
  required_version = ">= 1.6.0"
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.0" }
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = { ManagedBy = "Terraform", Project = var.project, Day = "Day23" } }
}
