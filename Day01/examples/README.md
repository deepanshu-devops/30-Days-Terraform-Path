# Day 01 Examples

## Example 1: Minimal VPC (Learning)

The simplest possible Terraform config — just a VPC. See `../code/main.tf`.

## Example 2: Multi-Region VPC

```hcl
# Provision the same VPC config in two regions using provider aliases
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

resource "aws_vpc" "us" {
  provider   = aws.us_east
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "vpc-us-east" }
}

resource "aws_vpc" "eu" {
  provider   = aws.eu_west
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "vpc-eu-west" }
}
```

## Example 3: Using Data Sources (Read-Only)

```hcl
# Read the current AWS account and region without creating anything
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "account_info" {
  value = "Account: ${data.aws_caller_identity.current.account_id} | Region: ${data.aws_region.current.name}"
}
```

Run with: `terraform apply -target=data.aws_caller_identity.current`

## Example 4: Terraform Console (REPL)

```bash
# Interactive REPL for testing expressions
terraform console

# Inside console:
> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"

> upper("hello terraform")
"HELLO TERRAFORM"

> length(["a", "b", "c"])
3
```

## What to Practice

1. Run `terraform init` and observe the `.terraform/` directory created
2. Run `terraform plan` — note how it says "1 to add"
3. Run `terraform apply` — inspect the VPC in the AWS Console
4. Run `terraform plan` again — it should say "No changes"
5. Manually add a tag to the VPC in the Console, then run `terraform plan` again — note drift detection
6. Run `terraform destroy` to clean up
