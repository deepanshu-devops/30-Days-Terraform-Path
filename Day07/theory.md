# Day 07 — Terraform Functions & Expressions

## WHAT
HCL provides a rich set of built-in functions for transforming and combining values. Functions cannot be user-defined — only the built-ins are available.

## Key Function Categories

### String Functions
```hcl
locals {
  upper    = upper("hello")           # "HELLO"
  lower    = lower("WORLD")           # "world"
  trimmed  = trimspace("  hi  ")      # "hi"
  replaced = replace("hello", "l", "r") # "herro"
  joined   = join(", ", ["a", "b"])   # "a, b"
  split_v  = split(",", "a,b,c")      # ["a", "b", "c"]
  formatted = format("%-10s | %d", "test", 42)
  templ    = templatefile("${path.module}/user_data.tpl", {
    db_host = "db.example.com"
    db_port = 5432
  })
}
```

### Numeric Functions
```hcl
locals {
  max_val = max(1, 2, 3)    # 3
  min_val = min(1, 2, 3)    # 1
  abs_val = abs(-5)          # 5
  ceil_v  = ceil(1.2)        # 2
  floor_v = floor(1.9)       # 1
  pow_v   = pow(2, 10)       # 1024
}
```

### Collection Functions
```hcl
locals {
  my_list  = ["c", "a", "b"]
  sorted   = sort(my_list)                    # ["a", "b", "c"]
  reversed = reverse(my_list)                 # ["b", "a", "c"]
  flattened = flatten([["a", "b"], ["c"]])    # ["a", "b", "c"]
  distinct  = distinct(["a", "a", "b"])       # ["a", "b"]
  list_len  = length(my_list)                 # 3
  elem      = element(my_list, 1)             # "a"
  contains  = contains(my_list, "a")          # true

  my_map   = { a = 1, b = 2, c = 3 }
  keys_v   = keys(my_map)                     # ["a", "b", "c"]
  values_v = values(my_map)                   # [1, 2, 3]
  merged   = merge({ a = 1 }, { b = 2 })      # { a=1, b=2 }
  lookup_v = lookup(my_map, "d", "default")   # "default"
}
```

### Type Conversion
```hcl
locals {
  to_str  = tostring(42)      # "42"
  to_num  = tonumber("42")    # 42
  to_bool = tobool("true")    # true
  to_list = tolist(["a","b"]) # ["a", "b"]
  to_map  = tomap({ a = 1 })
  to_set  = toset(["a","b","a"]) # {"a","b"}
}
```

### IP Network Functions
```hcl
locals {
  # Split 10.0.0.0/16 into /24 subnets
  subnet_1 = cidrsubnet("10.0.0.0/16", 8, 1)   # 10.0.1.0/24
  subnet_2 = cidrsubnet("10.0.0.0/16", 8, 2)   # 10.0.2.0/24
  
  host     = cidrhost("10.0.1.0/24", 10)        # 10.0.1.10
  prefix   = cidrnetmask("10.0.0.0/16")         # 255.255.0.0
}
```

### For Expressions
```hcl
locals {
  # Transform a list
  upper_names = [for name in var.names : upper(name)]
  
  # Filter a list
  prod_names = [for env in var.envs : env if env != "dev"]
  
  # Transform a map
  tagged_resources = {for k, v in var.resources : k => merge(v, { managed_by = "terraform" })}
  
  # List to map
  name_map = {for idx, name in var.names : name => idx}
}
```

### Conditionals
```hcl
locals {
  instance_type  = var.environment == "production" ? "t3.large" : "t3.micro"
  log_level      = var.debug ? "DEBUG" : "INFO"
  optional_value = var.enable_feature ? var.feature_value : null
}
```

---

## Audience-Level Explanations

### 🟢 Beginner
Functions transform values. Need all your environment names in uppercase? `upper()`. Need to build a subnet CIDR from a VPC CIDR? `cidrsubnet()`. The Terraform console is your playground.

### 🔵 Intermediate
Most powerful patterns: `for` expressions for collection transformations, `merge()` for tag combining, `cidrsubnet()` for network calculation.

### 🟠 Advanced
`templatefile()` is powerful for user_data scripts — keeps your bash scripts in `.tpl` files with proper syntax highlighting, uses Terraform variables.

### 🔴 Expert
Functions are evaluated at plan time. If a value is "known only after apply", functions on it also return unknown. This affects `count`, `for_each`, and output values.
