# Day27 Examples

## Running the Examples

```bash
cd ../code
terraform init
terraform plan
terraform apply -auto-approve
terraform output
terraform destroy -auto-approve
```

## Additional Examples
See theory.md for extended code samples for all audience levels (Beginner → Expert).

## Key Commands for This Day
```bash
# Validate syntax
terraform validate

# Format code
terraform fmt

# Interactive console (test expressions)
terraform console

# Show dependency graph (requires graphviz)
terraform graph | dot -Tsvg > graph.svg
```
