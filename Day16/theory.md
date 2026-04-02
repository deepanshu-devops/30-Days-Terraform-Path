# Day 16 — Securing Secrets with Vault & AWS Secrets Manager

## Real-Life Example 🏗️

**The Git History Problem:**  
A developer adds this to `terraform.tfvars`:
```hcl
db_password = "MyProdDB-2024-SecurePass!"
```

Commits it. The file is in `.gitignore` so it never shows in the repo... or so they think.  
A new engineer clones the repo and runs `git log --all --full-history -- terraform.tfvars`.  
The file appears in history. The password is visible. It has been there for 4 months.

The password must now be rotated across all environments that share it.  
**Total impact: 3 hours of rotation work, 15 minutes of planned downtime.**

**The correct approach:** secrets never touch the filesystem. They're fetched at apply time from a secrets manager.

---

## Why Not Store Secrets in Code or tfvars?

| Location | Problem |
|----------|---------|
| `main.tf` | In Git forever, visible to anyone with repo access |
| `terraform.tfvars` | Easy to accidentally commit; stays in git history even after deletion |
| Terraform state | State IS encrypted (if you set up KMS) but still — minimize exposure |
| CI/CD environment variables | Better — but prefer fetching from a secrets manager at runtime |

---

## AWS Secrets Manager Pattern

```hcl
# Step 1: Create the secret in Terraform (or manually in AWS console)
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/master-password"
  description             = "RDS master password for prod"
  recovery_window_in_days = 7    # 7-day grace period before permanent deletion
}

# Step 2: Store the secret value (use random_password to generate it)
resource "random_password" "db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# Step 3: Read it back in the same config (or in a different stack)
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  depends_on = [aws_secretsmanager_secret_version.db_password]
}

# Step 4: Use it — the password never appears in any .tf file
resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ↑ Fetched at apply time. Not stored in code. Encrypted in state.
}
```

---

## HashiCorp Vault Pattern

Vault goes further: it can generate **dynamic credentials** that expire automatically.

```hcl
provider "vault" {
  address = "https://vault.internal.company.com"
  # Auth: VAULT_TOKEN env var, AWS IAM auth, or OIDC
}

# Static secret
data "vault_generic_secret" "db" {
  path = "secret/prod/database"
}

# Dynamic AWS credentials (Vault generates fresh keys per apply)
data "vault_aws_access_credentials" "terraform" {
  backend = "aws"
  role    = "terraform-execution-role"
  # Vault calls AWS STS, returns short-lived access keys
  # Keys expire in 1 hour — leaked credentials auto-expire
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
}
```

---

## Sensitive Variables and Outputs

```hcl
# Mark a variable as sensitive — value is redacted in plan output and logs
variable "db_password" {
  description = "Database password. Inject via TF_VAR_db_password."
  type        = string
  sensitive   = true
}

# Mark an output as sensitive — shown as <sensitive> in apply output
output "db_connection_string" {
  description = "Full database connection string"
  value       = "postgres://${var.db_user}:${var.db_password}@${aws_db_instance.main.endpoint}/mydb"
  sensitive   = true
}

# To read a sensitive output:
terraform output -raw db_connection_string    # writes raw value to stdout
terraform output -json | jq .db_connection_string.value  # JSON, unredacted
```

---

## CI/CD: Injecting Secrets Without Storing Them

```bash
# In GitHub Actions secrets: store AWS credentials or Vault token
# At pipeline runtime, fetch and inject:

export TF_VAR_db_password=$(aws secretsmanager get-secret-value   --secret-id prod/database/master-password   --query SecretString   --output text)

terraform apply    # picks up TF_VAR_db_password automatically
```

---

## Security Checklist for Secrets

```
✅ encrypt = true on S3 backend (state may contain secret values)
✅ sensitive = true on any variable or output containing secrets
✅ *.tfvars in .gitignore (never commit real values)
✅ terraform.tfvars.example in Git (document the shape, no real values)
✅ Never default = "password" on sensitive variables
✅ Use data sources, not hardcoded values
✅ Rotate secrets regularly (Secrets Manager can automate this)
```
