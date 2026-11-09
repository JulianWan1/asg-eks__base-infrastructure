# ============================================================================
# Cost guardrail. A monthly COST budget with two alerts:
#   - ACTUAL     > 80%  : you've already spent $16 of $20 this month.
#   - FORECASTED > 100% : AWS projects you'll blow $20 at the current run-rate —
#                         this is the one that catches "I left a NAT gateway on
#                         overnight" BEFORE the money is gone.
#
# Budgets is an account-global service; it works fine created from any region.
# This budget is account-WIDE on purpose: it catches everything, including
# resources you forgot to tag. (To scope it to just Project=devops-lab you'd add
# a cost_filter on that tag — but tag-based cost filters require activating the
# tag as a cost-allocation tag in the Billing console first, which Terraform
# can't fully manage and takes ~24h to take effect. Account-wide is safer here.)
# ============================================================================
resource "aws_budgets_budget" "monthly" {
  name         = "asg-eks-devops-lab-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
