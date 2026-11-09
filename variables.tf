variable "region" {
  description = "AWS region for the lab (ap-southeast-1 = Singapore, ap-southeast-3 = Jakarta)."
  type        = string
  default     = "ap-southeast-1"
}

variable "state_bucket_name" {
  description = <<-EOT
    Name of the S3 bucket that holds remote state for the live/ tier.
    S3 bucket names are GLOBAL across all AWS accounts, so this must be unique
    to you — include your account id or initials, e.g. devops-lab-tfstate-123456789012.
  EOT
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "devops-lab-tf-locks"
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Alerts fire as spend approaches it."
  type        = number
  default     = 20
}

variable "budget_alert_email" {
  description = "Email address that receives budget alerts (you must confirm the subscription from your inbox)."
  type        = string
}
