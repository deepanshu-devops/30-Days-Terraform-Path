output "ci_role_arn" { description = "Terraform CI role ARN — use in GitHub Actions"; value = aws_iam_role.terraform_ci.arn }
output "ci_role_name" { description = "Role name"; value = aws_iam_role.terraform_ci.name }
