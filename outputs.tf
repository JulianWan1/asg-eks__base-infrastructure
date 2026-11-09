output "state_bucket" {
  description = "S3 bucket name for remote state."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "DynamoDB table name for state locking."
  value       = aws_dynamodb_table.locks.name
}

output "region" {
  value = var.region
}

# Copy-paste-ready backend block for the live/ tier. After `bootstrap-apply`,
# run `terraform -chdir=infra/bootstrap output -raw backend_config` and paste
# the result into live/backend.tf.
output "backend_config" {
  description = "Backend block for the live/ tier."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.state.id}"
        key            = "live/terraform.tfstate"
        region         = "${var.region}"
        dynamodb_table = "${aws_dynamodb_table.locks.name}"
        encrypt        = true
      }
    }
  EOT
}
