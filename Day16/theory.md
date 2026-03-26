# Day 16 — Securing Secrets with Vault & AWS Secrets Manager

## 5W + 1H

### WHAT
Secrets management means keeping sensitive values (passwords, API keys, private keys) out of code, state files, and CI/CD logs — while still making them available to Terraform at apply time.

### WHY IT MATTERS
- Secrets in Git = permanent exposure (commit history never forgets)
- Secrets in `.tfvars` = accidental commit risk
- Secrets in plain state = anyone with S3 access can read them

---

## Option 1: AWS Secrets Manager

```hcl
# Store the secret in AWS Secrets Manager first:
# aws secretsmanager create-secret --name prod/database/password --secret-string "mySecurePass123"

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "main" {
  identifier        = "prod-db"
  engine            = "postgres"
  instance_class    = "db.t3.medium"
  allocated_storage = 20
  username          = "dbadmin"
  password          = data.aws_secretsmanager_secret_version.db_password.secret_string
  skip_final_snapshot = true
}
```

Secret rotation with Terraform:
```hcl
resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
  rotation_rules {
    automatically_after_days = 30
  }
}
```

## Option 2: HashiCorp Vault

```hcl
provider "vault" {
  address = "https://vault.internal.company.com"
  # Auth via: VAULT_TOKEN env var, or AWS auth, or OIDC
}

# Static secret
data "vault_generic_secret" "db" {
  path = "secret/prod/database"
}

# Dynamic secret (Vault generates short-lived credentials)
data "vault_aws_access_credentials" "deploy" {
  backend = "aws"
  role    = "terraform-deploy"
  # Returns fresh, short-lived AWS creds for this apply
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
}
```

## Rules for Secret Hygiene

```hcl
# 1. Mark outputs sensitive
output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true   # Redacted in plan/apply output
}

# 2. Never put secrets in variable defaults
variable "db_password" {
  type      = string
  sensitive = true
  # NO default = "..." here — inject via TF_VAR_db_password env var
}

# 3. Encrypt state
terraform {
  backend "s3" {
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:...:key/..."
  }
}
```

## .gitignore for Terraform projects
```
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars          # Any file with actual values
!*.tfvars.example # But keep example templates
.terraform.tfstate.lock.info
crash.log
```

---

## Audience Levels

### 🟢 Beginner
Never type a password directly into a `.tf` file or `.tfvars`. Use AWS Secrets Manager to store it and `data "aws_secretsmanager_secret_version"` to fetch it.

### 🔵 Intermediate
Use IAM roles for Terraform's own AWS credentials — never static access keys. CI/CD tools should assume an IAM role via OIDC, not use stored secrets.

### 🟠 Advanced
Vault dynamic secrets: instead of a long-lived DB password, Vault generates a fresh username/password pair for each Terraform apply. Validity: 1 hour. If leaked, it expires automatically.

### 🔴 Expert
Build a Vault policy that only allows Terraform to read the specific paths it needs. Audit every secret access via Vault audit log → CloudWatch. Use Vault's AppRole auth for CI/CD instead of token-based auth.
