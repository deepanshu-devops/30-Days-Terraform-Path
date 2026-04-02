# Day 27 — Top 5 Terraform Mistakes I Made (and How to Fix Them)

## Real-Life Example 🏗️

These are not hypothetical. Each one happened. Each one caused a real incident. The fixes took less than an hour. The incidents took hours or days to recover from.

---

## Mistake 1: Local State in Production

**What happened:**  
I was the only person who could run Terraform — the state file was on my laptop. One day my laptop refused to boot. I had to recover infrastructure state from memory by importing 43 resources one by one over two days.

**The fix:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Rule:** Remote state. Day one. Every project. Non-negotiable.

---

## Mistake 2: No State Locking

**What happened:**  
Two engineers both needed to deploy before a deadline. They coordinated on Slack but the timing overlapped by 3 minutes. Both read the same state version, both wrote back. The state showed resources that had been deleted and missed resources that existed. 4-hour incident to reconstruct state.

**The fix:**  
`dynamodb_table = "terraform-state-lock"` in the backend config. The second apply waits. No corruption. Ever.

---

## Mistake 3: Secrets Committed to Git

**What happened:**  
A database password was in `terraform.tfvars`. The file was in `.gitignore`... but someone added `!terraform.tfvars` to an exception rule in a child `.gitignore`. Password committed. Sat in history for 5 months before a security audit found it.

**The fix:**
```hcl
# Never in .tfvars. Always from Secrets Manager:
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database/password"
}
resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db.secret_string
}
```

**Rule:** `*.tfvars` in `.gitignore`. Create `.tfvars.example` to document the shape.

---

## Mistake 4: No Module Version Pinning

**What happened:**  
Shared VPC module, no version pin in any of 6 calling projects. A colleague renamed a variable as part of a refactor. All 6 CI/CD pipelines failed simultaneously. 3 hours of coordinated emergency work across 3 teams.

**The fix:**
```hcl
module "vpc" {
  source = "git::https://github.com/org/modules.git//vpc?ref=v1.2.0"
  # NEVER: source = "git::...//vpc"  or  source = "git::...//vpc?ref=main"
}
```

**Rule:** Always pin. Treat modules like APIs. Breaking changes = major version bump. CHANGELOG required.

---

## Mistake 5: Running apply Without Reviewing plan

**What happened:**  
Friday afternoon. Quick change. Run apply directly. Terraform's plan included destroying an RDS parameter group that was being recreated with a different name — something I didn't expect, caused by a naming refactor I'd forgotten about. Parameter group is tied to the RDS instance. Recreating it means the RDS instance has to be replaced too. Service went down.

If I had run `plan` first, I would have seen the `-/+ replace` on the RDS instance and stopped.

**The fix:**
```bash
# Always save and review the plan
terraform plan -out=tfplan.binary
terraform show tfplan.binary   # read every line
terraform apply tfplan.binary  # applies the exact reviewed plan

# In CI/CD: plan posts to PR, apply runs after approval
```

**Rule:** `plan` is free. `apply` has consequences. `destroy` is forever. Never skip plan.

---

## Bonus Mistakes

### Mistake 6: Using count Instead of for_each for Variable Collections
Removing an item from the middle of a `count` list destroys all subsequent resources.  
**Fix:** Use `for_each` with string keys.

### Mistake 7: No `deletion_protection` on Critical Resources
```hcl
resource "aws_db_instance" "prod" {
  deletion_protection = true   # terraform destroy will fail unless this is false first
}
```

### Mistake 8: AdministratorAccess on the Terraform Role
If compromised: full account access.  
**Fix:** Scope to exactly what Terraform manages. See Day 17.

### Mistake 9: Modifying State File Manually
Even one wrong character in the JSON = corrupt state.  
**Fix:** Use `terraform state mv`, `terraform state rm`, `terraform import` instead.

### Mistake 10: Applying to Production on Friday Afternoon
The blast radius of a Friday apply extends through the entire weekend.  
**Fix:** Change freeze policy: no production applies after 3pm Friday.

---

## The Pattern

Every mistake has the same root cause: **prioritising speed over discipline**.

The fixes aren't complex. They take 10-30 minutes to implement. But they require doing them *before* the incident, not after.

The best time to set up DynamoDB locking was when you created the project. The second best time is now.
