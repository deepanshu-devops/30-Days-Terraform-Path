# Day 26 — Cost Estimation with Infracost

## Real-Life Example 🏗️

**The Surprise AWS Bill:**  
A developer submits a PR: "Add NAT Gateway for private subnet connectivity." The change looks right. Code review passes. It's applied Monday morning.

Tuesday: the cloud cost alert fires. This week's bill is $32 higher than expected. The NAT Gateway costs $32.40/month — nobody calculated this before applying.

Next month: another PR adds 3 more NAT Gateways (one per AZ for HA). Now it's $97.20/month extra. Still nobody catches it.

Six months later: "Why is our AWS bill $800/month higher than a year ago?"

**With Infracost:**  
The NAT Gateway PR gets a comment: "💰 This change will increase monthly cost by +$32.40/month (+8%)". The reviewer asks: "Do we need NAT for dev? Can we use a VPC endpoint instead?" Cost saved: $32.40/month.

---

## What Infracost Does

Infracost reads your Terraform code and uses AWS pricing APIs to estimate the monthly cost before you apply anything.

```bash
infracost breakdown --path .

# Output:
# Name                                  Qty  Unit     Monthly Cost
# ─────────────────────────────────────────────────────────────────
# aws_nat_gateway.main
#  └─ NAT gateway                         1  hours          $32.40
# aws_eip.nat
#  └─ IP address (if unattached)          1  months          $3.65
# aws_eks_node_group.general
#  └─ Instance (m5.large, on-demand)      3  hours          $98.55
# aws_db_instance.main
#  ├─ Instance (db.r6g.large, multi-AZ)  1  hours         $210.24
#  └─ Storage (gp3, 100 GB)            100  GB              $13.80
# ─────────────────────────────────────────────────────────────────
# TOTAL                                                    $358.64/month
```

---

## Setup

```bash
# Install
brew install infracost
# or: curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Authenticate (free — creates an account for the dashboard)
infracost auth login

# Verify
infracost --version
```

---

## Core Commands

```bash
# Show cost breakdown for current directory
infracost breakdown --path .

# Show cost DIFFERENCE vs the main branch (perfect for PR review)
infracost diff --path . --compare-to main

# Compare two specific plan files
infracost diff   --path current.tfplan.json   --compare-to previous.tfplan.json

# Generate cost report as HTML
infracost breakdown --path . --format html > cost-report.html

# Generate for CI/CD (JSON)
infracost breakdown --path . --format json > infracost.json
```

---

## GitHub Actions Integration

```yaml
# .github/workflows/infracost.yml
name: Infracost

on:
  pull_request:
    branches: [main]

jobs:
  infracost:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate Infracost diff
        run: |
          infracost diff             --path=.             --format=json             --compare-to-commit=${{ github.event.pull_request.base.sha }}             --out-file=infracost.json

      - name: Post cost estimate as PR comment
        uses: infracost/actions/comment@v3
        with:
          path: infracost.json
          behavior: update    # update existing comment, don't create new ones
```

**Result — PR comment:**
```
💰 Infracost estimate

Monthly cost will increase by $32.40/month (+8%)

+ aws_nat_gateway.main         +$32.40/month
+ aws_eip.nat                   +$3.65/month (if unattached)

Previous monthly cost:   $322.59
New monthly cost:        $358.64
```

---

## Cost Policy (Block Expensive PRs)

```bash
# Fail the PR if monthly cost increase exceeds $100
infracost comment github   --path infracost.json   --policy-path infracost-policy.rego
```

```rego
# infracost-policy.rego
package infracost

deny[msg] {
  increase := input.diffTotalMonthlyCost
  increase > 100
  msg := sprintf(
    "Cost increase of $%.2f/month exceeds the $100/month budget limit for a single PR.",
    [increase]
  )
}
```

---

## Resources Infracost Can Price

- EC2 instances + EBS volumes
- NAT Gateways + Elastic IPs
- RDS instances + storage
- EKS clusters + node groups
- Load Balancers (ALB, NLB)
- S3 (storage + requests)
- Lambda
- CloudFront distributions
- Route53 queries
- ElastiCache
- MSK (Kafka)
