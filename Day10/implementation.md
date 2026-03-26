# Day 10 — Implementation: Using the VPC Module

## Directory Structure

```
Day10/
  code/
    modules/
      vpc/
        main.tf        (the module code)
        variables.tf   (inputs)
        outputs.tf     (outputs)
        versions.tf    (version constraints)
    main.tf            (root module — calls the vpc module)
    terraform.tfvars
```

## Root module main.tf

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

module "vpc" {
  source = "./modules/vpc"

  name               = "day10-learning"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway   = false  # Save cost in learning
  single_nat_gateway   = true

  tags = { Environment = "learning", Day = "Day10" }
}

output "vpc_id"            { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
```

## Run it

```bash
cd Day10/code
terraform init  # Downloads the module (local path — no download needed)
terraform plan
terraform apply -auto-approve
terraform output
terraform destroy -auto-approve
```

## Key Insight
Notice how the root module is now just ~20 lines.
All the VPC complexity is hidden in the module.
This is the power of modules.
