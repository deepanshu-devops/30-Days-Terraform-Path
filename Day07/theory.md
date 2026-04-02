# Day 07 — Terraform Functions & Expressions

## Real-Life Example 🏗️

**Scenario:** You need to create subnets across all AZs in a region automatically.  
us-east-1 has 6 AZs. eu-west-1 has 3. You don't want to hardcode either count or CIDR blocks.

```hcl
locals {
  # cidrsubnet carves /24 blocks out of a /16 automatically
  # cidrsubnet("10.0.0.0/16", 8, 0) → "10.0.0.0/24"
  # cidrsubnet("10.0.0.0/16", 8, 1) → "10.0.1.0/24"
  # cidrsubnet("10.0.0.0/16", 8, 2) → "10.0.2.0/24"
  subnet_cidrs = [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
}

resource "aws_subnet" "public" {
  count             = var.subnet_count
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}
```

Set `subnet_count = 3` → get three correctly-CIDRed subnets in three different AZs. No hardcoding anywhere.

---

## String Functions

```hcl
upper("hello world")                    # "HELLO WORLD"
lower("AWS-PROD-VPC")                   # "aws-prod-vpc"
title("hello world")                    # "Hello World"
trimspace("  hello  ")                  # "hello"
replace("my_project_name", "_", "-")    # "my-project-name" (safe for S3 bucket names)
format("%-20s | %05d", "server", 42)   # "server               | 00042"
join(", ", ["a", "b", "c"])             # "a, b, c"
split(",", "us-east-1,eu-west-1")       # ["us-east-1", "eu-west-1"]
substr("hello terraform", 6, 9)         # "terraform"
startswith("prod-vpc", "prod")          # true
endswith("my-bucket", "bucket")         # true

# Multiline template
templatefile("${path.module}/user_data.sh.tpl", {
  db_host = "mydb.example.com"
  db_port = 5432
})
```

## Number Functions

```hcl
max(1, 5, 3, 2)       # 5
min(1, 5, 3, 2)       # 1
abs(-42)              # 42
ceil(1.2)             # 2    (round up)
floor(1.9)            # 1    (round down)
round(1.5)            # 2    (round to nearest)
pow(2, 10)            # 1024
log(1024, 2)          # 10
```

## Collection Functions

```hcl
length(["a", "b", "c"])                         # 3
element(["a", "b", "c"], 1)                     # "b"
contains(["dev", "prod"], "prod")               # true
distinct(["a", "b", "a", "c"])                  # ["a", "b", "c"]
flatten([["a", "b"], ["c", "d"]])               # ["a", "b", "c", "d"]
sort(["c", "a", "b"])                           # ["a", "b", "c"]
reverse(["a", "b", "c"])                        # ["c", "b", "a"]
slice(["a","b","c","d"], 1, 3)                  # ["b", "c"]

# Map functions
keys({a = 1, b = 2, c = 3})                    # ["a", "b", "c"]
values({a = 1, b = 2, c = 3})                  # [1, 2, 3]
merge({a=1}, {b=2}, {a=99})                     # {a=99, b=2}  — last wins
lookup({a=1, b=2}, "c", "default")              # "default"

# Type conversion
toset(["a", "b", "a"])                          # {"a", "b"}  — deduplicates
tolist(toset(["a", "b"]))                       # ["a", "b"]
tostring(42)                                    # "42"
tonumber("42")                                  # 42
```

## Network Functions — Essential for Infrastructure

```hcl
# cidrsubnet: carve a subnet from a larger block
cidrsubnet("10.0.0.0/16", 8, 0)   # "10.0.0.0/24"
cidrsubnet("10.0.0.0/16", 8, 1)   # "10.0.1.0/24"
cidrsubnet("10.0.0.0/16", 8, 10)  # "10.0.10.0/24"
cidrsubnet("10.0.0.0/8",  16, 1)  # "10.0.1.0/24"

# cidrhost: get a specific host address from a CIDR
cidrhost("10.0.1.0/24", 1)        # "10.0.1.1"  (gateway)
cidrhost("10.0.1.0/24", 10)       # "10.0.1.10"
cidrhost("10.0.1.0/24", -2)       # "10.0.1.254" (last usable)

cidrnetmask("10.0.0.0/16")        # "255.255.0.0"
```

## For Expressions — Transform Collections

```hcl
# List → transformed list
[for name in var.names : upper(name)]
# var.names = ["alice","bob"] → ["ALICE","BOB"]

# List → filtered list
[for e in var.envs : e if e != "prod"]
# ["dev","staging","prod"] → ["dev","staging"]

# Map → list
[for k, v in var.instance_sizes : "${k}: ${v}"]
# {web="t3.small",api="t3.medium"} → ["web: t3.small","api: t3.medium"]

# List → map  (must produce unique keys)
{for idx, name in var.names : name => idx}
# ["alice","bob"] → {alice=0, bob=1}

# Map → transformed map
{for k, v in var.config : k => merge(v, {managed_by = "terraform"})}
```

## Conditional Expressions (Ternary)

```hcl
# condition ? value_if_true : value_if_false

instance_type  = var.environment == "prod" ? "t3.large"  : "t3.micro"
backup_days    = var.environment == "prod" ? 30           : 7
nat_count      = var.environment == "prod" ? length(var.azs) : 0
enable_logging = var.environment == "prod" ? true         : false

# Nested conditional
instance_class = (
  var.environment == "prod"    ? "db.r6g.large" :
  var.environment == "staging" ? "db.t3.small"  :
  "db.t3.micro"
)
```

---

## Test Everything in `terraform console`

Before putting any function in code, test it:

```bash
terraform console    # opens a REPL with access to your config

> cidrsubnet("10.0.0.0/16", 8, 3)
"10.0.3.0/24"

> [for i in range(4) : cidrsubnet("10.0.0.0/16", 8, i+1)]
["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24","10.0.4.0/24"]

> merge({a=1},{a=99,b=2})
{a=99, b=2}

> "prod" == "prod" ? "db.r6g.large" : "db.t3.micro"
"db.r6g.large"

> [for e in ["dev","staging","prod"] : e if e != "prod"]
["dev","staging"]
```
