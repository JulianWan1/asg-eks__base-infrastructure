# ============================================================================
# Remote state backend: an S3 bucket (the state) + a DynamoDB table (the lock).
# These are PERMANENT. They must outlive every `make down` / `make nuke` of the
# live tier, so both carry prevent_destroy and live here in the bootstrap tier
# that is applied once and then left alone.
# ============================================================================

# --- State bucket -----------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # Guard rail: a stray `terraform destroy` in this directory will error instead
  # of deleting the bucket that holds all your other state. To decommission at
  # the very end of the project, remove this block first, then destroy.
  # uncomment once confirmed that we want to maintain the resource
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Versioning lets you roll back a corrupted or bad-apply state file to a prior
# version instead of losing it. Non-negotiable for a state bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES256) encrypts objects at rest with zero extra cost and zero KMS
# request charges. Switch to sse_algorithm = "aws:kms" only if you need a
# customer-managed key and are willing to pay per-request KMS charges.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State files can contain secrets (DB passwords, etc.). This bucket must never
# be public — all four flags on.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lock table -------------------------------------------------------------
# Terraform grabs a lock row here before every apply, so two runs (you + a CI
# job, say) can't mutate the same state at once. PAY_PER_REQUEST means you pay
# per lock/unlock — effectively $0 for a lab, and nothing to leave running.
#
# NOTE: the hash_key MUST be exactly "LockID" — that's the key name the S3
# backend writes. Don't rename it.
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # uncomment once confirmed that we want to maintain the resource
  # lifecycle {
  #   prevent_destroy = true
  # }
}
