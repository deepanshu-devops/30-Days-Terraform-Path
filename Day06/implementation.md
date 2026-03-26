# Day 06 — Implementation: Data Sources

## Key Commands

```bash
# After apply, see data source values
terraform output latest_ami_id    # Dynamically fetched AMI
terraform output account_id       # Your AWS account ID

# Use console to explore data sources interactively
terraform console
> data.aws_availability_zones.available.names
> data.aws_ami.amazon_linux_2023.image_id
> data.aws_caller_identity.current.arn
```

## Common Data Source Patterns

| Use Case | Data Source |
|---|---|
| Latest AMI | `data.aws_ami` |
| Current account | `data.aws_caller_identity` |
| Existing VPC | `data.aws_vpc` |
| Secrets | `data.aws_secretsmanager_secret_version` |
| SSM parameters | `data.aws_ssm_parameter` |
| IAM policy doc | `data.aws_iam_policy_document` |
| Route53 zone | `data.aws_route53_zone` |
