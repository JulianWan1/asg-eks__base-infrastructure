# The bootstrap tier deliberately has NO backend block. It creates the very S3
# bucket + DynamoDB table that every OTHER tier uses for remote state, so it
# cannot use them itself (chicken-and-egg). Its state stays local — see README.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # v6 is current; the split S3 resources below also work on v5.40+ if you
      # prefer to pin lower (change to ">= 5.40, < 7.0").
      version = "~> 6.0"
    }
  }
}
