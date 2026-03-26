# Day 03 — Implementation: Providers, Resources & State

## Learning Objectives
- Configure multiple providers in one Terraform config
- Use data sources to query existing infrastructure
- Understand resource meta-arguments (lifecycle, depends_on, count)
- Inspect and manipulate Terraform state

## Hands-On Steps

### 1. Apply the configuration

```bash
cd Day03/code
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

### 2. Inspect state after apply

```bash
# List all tracked resources
terraform state list

# Expected output:
# data.aws_ami.amazon_linux
# data.aws_availability_zones.available
# data.aws_caller_identity.current
# aws_s3_bucket.logs
# aws_security_group.web
# aws_subnet.public
# aws_vpc.eu
# aws_vpc.main
# random_pet.suffix

# Inspect a specific resource
terraform state show aws_vpc.main

# Show the full state as JSON
terraform show -json | jq '.values.root_module.resources[].address'
```

### 3. Experience state drift (manual)

```bash
# 1. Note the VPC name tag from the output
terraform output us_vpc_id

# 2. Go to AWS Console → VPC → Edit tags → Add a tag: manual=true

# 3. Run plan — see drift detected
terraform plan
# You should see: ~ update aws_vpc.main (due to tag change)

# 4. Apply to bring it back
terraform apply
```

### 4. State manipulation commands

```bash
# Rename a resource in state (doesn't touch real infra)
# terraform state mv aws_vpc.main aws_vpc.renamed

# Remove from state (real infra stays, Terraform forgets it)
# terraform state rm aws_s3_bucket.logs

# Import existing infra into state
# terraform import aws_vpc.existing vpc-0abc123456
```

### 5. Understand the dependency graph

```bash
# Generate dependency graph (requires Graphviz: brew install graphviz)
terraform graph | dot -Tsvg > graph.svg
open graph.svg
```

This visually shows:
- `aws_subnet.public` → depends on → `aws_vpc.main`
- `aws_security_group.web` → depends on → `aws_vpc.main`
- `aws_vpc.main` → depends on → `random_pet.suffix`

### 6. Clean up

```bash
terraform destroy
```

## Key Takeaways

1. **Providers** = plugins downloaded by `init`, configured with `provider {}` blocks
2. **Resources** = infrastructure objects; reference each other with `resource_type.name.attribute`
3. **Data sources** = read-only queries; use `data {}` blocks, reference with `data.type.name.attribute`
4. **State** = the source of truth for what Terraform manages; inspect with `terraform state` commands
5. **Dependency graph** = Terraform automatically figures out creation order from references
