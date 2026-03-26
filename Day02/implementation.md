# Day 02 — Implementation: Tool Comparison Hands-On

## Goal
Deploy identical infrastructure (S3 bucket with encryption + versioning) using all three tools to understand the experience difference.

---

## Part 1: Terraform

```bash
mkdir terraform-demo && cd terraform-demo
```

`main.tf`:
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "demo" {
  bucket = "terraform-demo-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

output "bucket_name" { value = aws_s3_bucket.demo.bucket }
```

```bash
terraform init && terraform apply -auto-approve
terraform destroy -auto-approve
```

---

## Part 2: CloudFormation

`cfn-template.yaml`:
```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: S3 bucket with encryption and versioning

Resources:
  DemoBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Delete
    Properties:
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256

Outputs:
  BucketName:
    Value: !Ref DemoBucket
```

```bash
aws cloudformation deploy \
  --template-file cfn-template.yaml \
  --stack-name demo-s3-stack

aws cloudformation describe-stacks --stack-name demo-s3-stack \
  --query "Stacks[0].Outputs"

aws cloudformation delete-stack --stack-name demo-s3-stack
```

---

## Part 3: Pulumi (TypeScript)

```bash
pulumi new aws-typescript --name pulumi-demo
```

Edit `index.ts`:
```typescript
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

const bucket = new aws.s3.BucketV2("demo", { forceDestroy: true });

new aws.s3.BucketVersioningV2("demoVersioning", {
  bucket: bucket.id,
  versioningConfiguration: { status: "Enabled" },
});

new aws.s3.BucketServerSideEncryptionConfigurationV2("demoEncryption", {
  bucket: bucket.id,
  rules: [{
    applyServerSideEncryptionByDefault: { sseAlgorithm: "AES256" },
  }],
});

export const bucketName = bucket.bucket;
```

```bash
pulumi preview
pulumi up
pulumi destroy
```

---

## Experience Comparison Table

| Step | Terraform | CloudFormation | Pulumi |
|---|---|---|---|
| Setup time | 2 min | 0 min (built-in) | 10 min (npm) |
| Config length | ~30 lines HCL | ~25 lines YAML | ~30 lines TS |
| Preview command | `terraform plan` | `aws cloudformation deploy --no-execute-changeset` | `pulumi preview` |
| Error messages | Verbose, helpful | AWS API errors (terse) | Verbose, helpful |
| State location | Local `.tfstate` | AWS-managed | Pulumi Cloud |
| Destroy | `terraform destroy` | `delete-stack` | `pulumi destroy` |

## Key Observations

1. **CloudFormation** had the least setup — no state file, native to AWS
2. **Terraform** was most familiar — plan output is clear and readable  
3. **Pulumi** required the most setup but felt natural for TypeScript devs
