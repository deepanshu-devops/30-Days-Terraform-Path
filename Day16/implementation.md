# Day 16 — Implementation: Secrets Management

## Steps

```bash
cd Day16/code
terraform init
terraform apply -auto-approve

# See that sensitive output is redacted
terraform output
# db_password = <sensitive>

# Access the value explicitly (only do this when needed)
terraform output -raw db_password

# Verify in AWS
aws secretsmanager get-secret-value --secret-id day16/database/password

# Clean up
terraform destroy -auto-approve
```

## Key Rules
| Rule | Why |
|---|---|
| Never `default = "password"` in variables | Ends up in plan output |
| Always `sensitive = true` on secret outputs | Prevents accidental logging |
| Use Secrets Manager or Vault | Centralized rotation + audit |
| Encrypt state with KMS | Secrets can be stored in state |
| Restrict who can read the state S3 bucket | State contains secrets |
