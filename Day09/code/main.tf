# Day09/code — State management scripts

# state_backup.sh — run before risky operations
#!/bin/bash
BUCKET="my-org-terraform-state"
KEY="$1"  # e.g., prod/vpc/terraform.tfstate
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_KEY="backups/${KEY%.*}_${TIMESTAMP}.tfstate"

echo "Backing up state..."
aws s3 cp "s3://${BUCKET}/${KEY}" "s3://${BUCKET}/${BACKUP_KEY}"
echo "Backup created: s3://${BUCKET}/${BACKUP_KEY}"
