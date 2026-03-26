# Day 17 — Implementation: IAM Least Privilege

## Setup the Terraform Execution Role

```bash
cd Day17/code
terraform init
terraform apply -auto-approve

# Note the role ARN from output
terraform output role_arn
```

## Use in GitHub Actions

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: <role_arn from output>
    aws-region: us-east-1
```

## Verify Permissions (IAM Policy Simulator)

```bash
# Test if the role can create a VPC
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformExecutionRole \
  --action-names ec2:CreateVpc \
  --resource-arns "*"

# Test that admin actions are denied
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformExecutionRole \
  --action-names iam:CreateUser \
  --resource-arns "*"
```
