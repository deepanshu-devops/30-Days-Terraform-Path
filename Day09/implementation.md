# Day 09 — Implementation: State Safety

## Must-Do Checklist Before Any Production Apply

```bash
# 1. Verify state is healthy
terraform plan 2>&1 | head -50

# 2. Backup state
aws s3 cp s3://my-state-bucket/prod/terraform.tfstate ./backup-$(date +%Y%m%d).tfstate

# 3. Check who else might be running apply
# (Check DynamoDB for existing lock)
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "my-state-bucket/prod/terraform.tfstate"}}'

# 4. Apply
terraform apply tfplan

# 5. Verify plan after apply
terraform plan  # Should show "No changes"
```

## If You Find Corruption

```bash
# Step 1: Don't panic. Don't apply.
# Step 2: Identify affected resources
terraform state list

# Step 3: For each affected resource, try to import
terraform import aws_vpc.main <vpc-id>

# Step 4: Run plan — verify it shows no unexpected destroys
terraform plan

# Step 5: If still broken, restore from S3 version
aws s3api list-object-versions --bucket my-state-bucket --prefix prod/
```
