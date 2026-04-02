aws_region         = "us-east-1"
project            = "day05"
environment        = "dev"
vpc_cidr           = "10.0.0.0/16"
subnet_count       = 2
enable_nat_gateway = false
owner_email        = "platform-team@company.com"

additional_tags = {
  CostCenter = "engineering"
  Team       = "platform"
}

# db_password = "..."  # Set via TF_VAR_db_password env var in CI/CD
