# Day 26 — Cost Estimation with Infracost

## WHAT
Infracost parses your Terraform code and estimates the monthly AWS cost — before you run `terraform apply`.

## Setup
```bash
# Install
brew install infracost

# Authenticate (free)
infracost auth login
```

## Basic Usage
```bash
# Estimate cost of current config
infracost breakdown --path .

# Diff: cost change vs main branch
infracost diff --path . --compare-to main

# Output format options
infracost breakdown --path . --format json       # Machine-readable
infracost breakdown --path . --format html > report.html  # Human report
infracost breakdown --path . --format table      # Default table
```

## Reading the Output
```
Name                                    Quantity  Unit           Monthly Cost

aws_eks_node_group.general
  Instance usage (m5.large, on-demand)       3  hours              $98.55
  CPU credits                                0  vCPU-hours           $0.00

aws_db_instance.main (db.r6g.large, multi-AZ)
  Database instance                          1  hours             $210.24
  Storage (gp3, 100 GB)                    100  GB                 $13.80

aws_nat_gateway.main (× 3)
  NAT Gateway                                3  hours              $97.20
  Data processed                             0  GB                  $0.00

TOTAL                                                           $419.79/month
```

## GitHub Actions Integration
```yaml
- name: Setup Infracost
  uses: infracost/actions/setup@v3
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Run Infracost
  run: |
    infracost diff \
      --path=. \
      --format=json \
      --compare-to-commit=${{ github.event.pull_request.base.sha }} \
      --out-file=infracost.json

- name: Post Infracost comment
  uses: infracost/actions/comment@v3
  with:
    path: infracost.json
    behavior: update  # Update existing comment on re-run
```

Result: every PR shows a cost diff comment:
```
💰 Cost Estimate
Monthly cost will increase by $32/month (+8%)

+ aws_nat_gateway.extra   +$32.40/month

Details: [link to full breakdown]
```

## Cost Policies (Block PRs that exceed budget)
```bash
# Fail if monthly cost increases by > $100
infracost diff --path . --format json --out-file /tmp/infracost.json
infracost comment github \
  --path /tmp/infracost.json \
  --repo $GITHUB_REPOSITORY \
  --pull-request $PR_NUMBER \
  --behavior new \
  --policy-path infracost-policy.rego
```

```rego
# infracost-policy.rego
package infracost

deny[msg] {
  increase := input.diffTotalMonthlyCost
  increase > 100
  msg := sprintf("Cost increase ($%.2f/month) exceeds $100/month budget limit", [increase])
}
```

## Audience Levels

### 🟢 Beginner
Run `infracost breakdown --path .` in your Terraform directory. You'll see exactly what your infrastructure will cost before creating it. Essential for learning what resources cost.

### 🔵 Intermediate
Add Infracost to your PR pipeline. Reviewers see cost impact alongside code changes. No more surprise bills.

### 🟠 Advanced
Use `infracost breakdown` in your module test pipeline — ensure modules don't become unexpectedly expensive after updates. Tag cost estimates by team, project, and environment.

### 🔴 Expert
Build a FinOps dashboard: Infracost cost estimates → cost actuals from AWS Cost Explorer → variance analysis. Alert when actual cost > estimated by >20%. Treat cost as a first-class engineering metric.
