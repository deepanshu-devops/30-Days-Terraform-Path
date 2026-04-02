output "state_bucket_name" {
  description = "S3 bucket name — use in backend config of all projects"
  value       = aws_s3_bucket.terraform_state.bucket
}
output "state_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.terraform_state.arn
}
output "lock_table_name" {
  description = "DynamoDB table name — use in backend config of all projects"
  value       = aws_dynamodb_table.terraform_lock.name
}
output "backend_config_snippet" {
  description = "Paste this into the terraform {} block of every project"
  value = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.bucket}"
      key            = "<your-project>/<env>/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
      encrypt        = true
    }
  EOT
}
