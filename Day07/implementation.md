# Day 07 — Implementation: Functions

## Best Practice: Use terraform console to test functions

```bash
terraform init
terraform console

# Test string functions
> upper("hello terraform")
> lower("HELLO")
> format("%-10s: %d", "count", 42)
> join("-", ["prefix", "name", "suffix"])

# Test network functions
> cidrsubnet("10.0.0.0/16", 8, 1)
> cidrsubnet("10.0.0.0/16", 8, 2)
> cidrhost("10.0.1.0/24", 10)

# Test for expressions
> [for i in range(5) : i * 2]
> {for k, v in {a=1, b=2} : k => v * 10}

# Test conditionals
> true ? "yes" : "no"
> "production" == "production" ? "prod" : "non-prod"

# Exit console
> exit
```

## Apply and see outputs

```bash
terraform apply -auto-approve
terraform output
terraform output subnet_cidrs
terraform output common_tags
```
