################################################################################
# Day21 — main.tf
# Topic: Multi-Account AWS
# Real-life: Multi-account: A developer accidentally deletes an S3 bucket in prod while working on dev. Single account = one mistake affects everything. Multi-account: dev and prod are separate AWS accounts with separate credentials. A mistake in dev cannot touch prod.
################################################################################

variable "dev_account_id"  { type = string; default = "111111111111" }
variable "prod_account_id" { type = string; default = "222222222222" }

provider "aws" {
  alias  = "dev"
  region = var.aws_region
  assume_role { role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole" }
}
provider "aws" {
  alias  = "prod"
  region = var.aws_region
  assume_role { role_arn = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole" }
}

resource "aws_vpc" "dev_network" {
  provider   = aws.dev
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "dev-vpc", Account = "dev" }
}
resource "aws_vpc" "prod_network" {
  provider   = aws.prod
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "prod-vpc", Account = "prod" }
}
