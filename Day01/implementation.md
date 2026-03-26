# Day 01 — Implementation Guide: Your First Terraform Config

## Prerequisites
- Terraform CLI installed (`>= 1.6.0`)
- AWS CLI configured (`aws configure`)
- An AWS account with IAM permissions (EC2, VPC)
- Git initialized in your project folder

## Step-by-Step Implementation

### Step 1: Install Terraform

```bash
# macOS (Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify
terraform -version
```

### Step 2: Project Setup

```bash
mkdir my-first-terraform
cd my-first-terraform
git init
echo ".terraform/" >> .gitignore
echo "*.tfstate" >> .gitignore
echo "*.tfstate.backup" >> .gitignore
echo "*.tfvars" >> .gitignore
```

### Step 3: Write Your First Config

Create `main.tf`:

```hcl
# Specify which version of Terraform and providers to use
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "my-first-terraform-vpc"
    ManagedBy   = "Terraform"
    Environment = "learning"
  }
}
```

### Step 4: Run the Terraform Lifecycle

```bash
# Initialize — downloads providers, sets up backend
terraform init

# Validate syntax and configuration
terraform validate

# Format code consistently
terraform fmt

# Plan — see what will be created
terraform plan

# Apply — create the actual infrastructure
terraform apply

# Type 'yes' when prompted

# View outputs
terraform show

# Clean up — destroy what we created
terraform destroy
```

### Step 5: Understanding the Output

After `terraform plan`, you'll see:
```
Terraform will perform the following actions:

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + id                                   = (known after apply)
      + tags                                 = {
          + "Environment" = "learning"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "my-first-terraform-vpc"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

- `+` = will be created
- `~` = will be updated in-place
- `-` = will be destroyed
- `-/+` = will be destroyed and recreated

### Step 6: Inspect State

```bash
# List all resources in state
terraform state list

# Show details for a specific resource
terraform state show aws_vpc.main
```

## Verification Checklist

- [ ] `terraform init` completes with "Terraform has been successfully initialized!"
- [ ] `terraform validate` returns "Success! The configuration is valid."
- [ ] `terraform plan` shows 1 resource to add
- [ ] `terraform apply` creates the VPC (visible in AWS Console)
- [ ] `terraform.tfstate` file exists locally
- [ ] `terraform destroy` removes the VPC cleanly

## What Just Happened?

```
main.tf (desired state)
    ↓
terraform init
    ↓  Downloads hashicorp/aws provider (~200MB)
.terraform/providers/...
    ↓
terraform plan
    ↓  Diff: desired state vs current state (empty)
Plan output (shows +1 VPC)
    ↓
terraform apply
    ↓  Calls AWS EC2 CreateVpc API
terraform.tfstate (records vpc-xxxxxxxx)
```

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `Error: No valid credential sources found` | AWS not configured | Run `aws configure` |
| `Error: Required plugins are not installed` | Did not run init | Run `terraform init` |
| `Error: Invalid resource type` | Wrong provider/resource name | Check provider docs |
| `Error: Unsupported argument` | Typo in attribute name | Run `terraform validate` |
