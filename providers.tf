provider "aws" {
  region = var.region

  # default_tags stamps EVERY taggable resource this provider creates, in this
  # tier and any tier that copies this block. This is what makes `Project`-based
  # cost tracking and "find everything the lab created" actually work, without
  # hand-tagging each resource. Tier is set per-tier so you can tell bootstrap
  # (permanent) resources apart from live (ephemeral) ones in the bill.
  default_tags {
    tags = {
      Project   = "asg-eks-devops-lab"
      ManagedBy = "terraform"
      Tier      = "bootstrap"
    }
  }
}
