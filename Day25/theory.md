# Day 25 — Drift Detection & How to Fix It

## Real-Life Example 🏗️

**The 3am Hotfix That Became Permanent:**  
Production is down. The on-call engineer finds the issue: a missing inbound rule in a security group. They add it in the AWS Console. Service restored. Incident over.

The next morning, they mean to update the Terraform code but get pulled into a meeting. Then another. The console change is forgotten.

Three months later, a platform engineer cleans up old Terraform configs. They run `terraform apply`. The security group is returned to its Terraform-defined state. The rule is removed. Production goes down again.

This is drift. And it's dangerous precisely because it's silent until someone runs `apply`.

---

## What is Drift?

Drift is when your real infrastructure diverges from your Terraform code and state.

```
Terraform State         Real Infrastructure (AWS)
──────────────          ─────────────────────────
sg_rule: port 443  ←→   sg_rule: port 443  (match ✅)
                         sg_rule: port 3000 (extra ⚠️)  ← drift

aws_vpc.main.tags:       aws_vpc.main.tags:
  Name = "prod-vpc"        Name = "prod-vpc"     (match ✅)
                            manual = "true"       (drift ⚠️)
```

---

## How Drift Happens

| Cause | Example |
|-------|---------|
| Emergency console fix | Add security group rule during incident |
| AWS auto-modification | ECS updates task definition revision |
| Another tool | Ansible changes EC2 user data |
| Wrong branch | Terraform run from outdated branch |
| Manual exploration | "Let me just try this in the console" |

---

## Detecting Drift

### Method 1: Manual Plan
```bash
terraform plan
# Any output that isn't "No changes" is drift
# ~ update aws_security_group.web (unexpected change)
# - destroy aws_s3_bucket.old (you didn't mean to destroy this)
```

### Method 2: Automated Nightly Drift Detection

```yaml
# .github/workflows/drift-detection.yml
name: Nightly Drift Detection

on:
  schedule:
    - cron: '0 6 * * *'    # 6am UTC every day

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}
          aws-region: us-east-1
      - name: Init
        run: terraform init
      - name: Check for drift
        id: plan
        run: |
          terraform plan -detailed-exitcode -no-color 2>&1
          echo "exit_code=$?" >> $GITHUB_OUTPUT
        continue-on-error: true
      - name: Alert on drift
        if: steps.plan.outputs.exit_code == '2'    # 2 = changes detected
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "⚠️ Terraform drift detected in prod!
Environment needs attention.
Run `terraform plan` to see the changes.",
              "channel": "#platform-alerts"
            }
```

`terraform plan -detailed-exitcode` returns:
- `0` = No changes (no drift)
- `1` = Error
- `2` = Changes detected = drift

---

## Fixing Drift

**Option 1: Revert to code (code is the source of truth)**
```bash
terraform apply    # removes or corrects the manual change
```

**Option 2: Codify the change (the manual change was intentional and correct)**
```hcl
# Update your Terraform code to include the manual change
resource "aws_security_group_rule" "hotfix_port_3000" {
  type        = "ingress"
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]    # Internal only
  security_group_id = aws_security_group.web.id
  description = "Added during incident 2024-01-15 — internal API access"
}
# Then: terraform plan → should show "No changes"
```

**Option 3: Import the new resource into state**
```bash
# A new resource was manually created — bring it into management
terraform import aws_security_group_rule.new_rule sg-0abc123_ingress_tcp_3000_3000_10.0.0.0/8
```

---

## Prevention: Make Manual Changes Impossible

```hcl
# Service Control Policy: deny console EC2 modifications to production resources
resource "aws_organizations_policy" "deny_manual_prod_changes" {
  type = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Statement = [{
      Effect    = "Deny"
      Action    = ["ec2:AuthorizeSecurityGroupIngress", "ec2:ModifyVpcAttribute"]
      Resource  = ["*"]
      Condition = {
        StringEquals = { "aws:RequestedRegion" = "us-east-1" }
        ArnNotLike   = { "aws:PrincipalArn" = "arn:aws:iam::*:role/TerraformCIRole" }
      }
    }]
  })
}
```

The strongest drift prevention: only the Terraform CI role can modify resources. Humans can read, but only the pipeline can write.
