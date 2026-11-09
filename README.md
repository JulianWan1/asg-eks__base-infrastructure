# infra/bootstrap — Phase 0

The infrastructure _for_ the infrastructure. Applied once, left alone. Creates
the support tools so Phase 1 (ASG) and 2 (EKS) have a safe foundation.

- **S3 bucket** — stores the state file for Phase 1+ (versioned, encrypted, private)
- **DynamoDB lock table** — prevents two Terraform runs from colliding
- **Budget alarm** — emails you when spending approaches $20/month
- **Auto-tagging** — stamps `Project=devops-lab` on every resource

## Scripts vs state

- **`.tf` files** (scripts) = the shopping list. What you _want_ to exist.
  Lives in your code repo.
- **`terraform.tfstate`** (state file) = the receipt. What was _actually_ built,
  including AWS IDs and details.

Terraform compares the two every time it runs to figure out what needs to
change — create, update, or delete.

## Why this tier has local state (chicken-and-egg)

Phase 0 creates the S3 bucket. You can't store state in a bucket that doesn't
exist yet. So Phase 0 keeps its receipt locally. Phase 1+ uses the bucket.

For a solo lab, committing `terraform.tfstate` from this dir is a reasonable
choice — there's nothing secret in it (just bucket/table names).

## Why Phase 1+ uses S3

Same reason you push code to GitHub:

1. **Shared source of truth.** When CI/CD (GitHub Actions) enters later, both
   your laptop and the pipeline need to see the same receipt.
2. **Can't accidentally lose it.** Losing state while resources are running
   means Terraform forgets they exist and you have to hunt them down manually.

## How the files connect

- **`versions.tf`** — minimum requirements (Terraform 1.6+, AWS plugin v6).
- **`variables.tf`** — defines the blanks to fill in (bucket name, email, budget).
- **`terraform.tfvars`** — your actual answers. Linked to `variables.tf` by
  matching names automatically (same name = connected).
- **`providers.tf`** — sets the AWS region and auto-tagging. Reads region from
  variables.
- **`state.tf`** — builds the S3 bucket and DynamoDB lock table.
- **`budget.tf`** — builds the $20/month spending alarm.
- **`outputs.tf`** — prints info Phase 1 needs (bucket name, lock table, a
  ready-to-paste backend config block).

## DynamoDB locking

Before Terraform edits the state file, it writes a row to the DynamoDB table
(grabs the lock). When done, it deletes the row. If another run sees the row,
it waits. The column is called `LockID` — hardcoded by Terraform, can't rename.

Nothing to do with the app's RDS database. Costs ~$0 on `PAY_PER_REQUEST`.
Phase 0 doesn't use it (local state). Phase 1+ will.

DynamoDB is optional on Terraform 1.10+ (`use_lockfile = true` does native S3
locking). We include it because it's the pattern in most existing codebases.

## Apply it (once)

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform plan
terraform apply
```

Then confirm the budget subscription — AWS emails your `budget_alert_email` a
confirmation link you must click, or alerts won't send.

## Wire up the live tier

```bash
terraform -chdir=infra/bootstrap output -raw backend_config > ../live/backend.tf
```

Writes the `backend "s3"` block into `live/` so Phase 1+ uses remote state.

## `prevent_destroy`

Not "protect these, delete the rest." If _any_ resource has `prevent_destroy`,
Terraform rejects the **entire** destroy. Nothing gets touched.

To practice applying and destroying: remove the `prevent_destroy` blocks first.
Put them back when done.

## Destroy order

Always destroy in reverse: Phase 1 first, then Phase 0. Deleting the S3 bucket
while Phase 1's state is in it means Terraform loses its receipt.

## Budget alarm details

- Watches **entire account** spend, not just tagged resources.
- Two alerts: already spent 80% ($16), and forecasted to hit 100% ($20).
- The forecast alert catches a NAT gateway left running _before_ the money is
  gone.
- Could be scoped to tagged resources only, but that requires manually
  activating the tag in the AWS Billing console (~24h, not Terraform-managed).
  Account-wide is simpler.

## Cost estimates (no free tier, 3 hrs/day, 20 days/month)

| Resource           | Rate/hour | 60 hours   |
| ------------------ | --------- | ---------- |
| NAT gateway        | $0.045    | $2.70      |
| EC2 (t3.micro)     | $0.012    | $0.72      |
| RDS (db.t4g.micro) | $0.018    | $1.08      |
| Load balancer      | $0.023    | $1.38      |
| **Total**          |           | **~$5.88** |

Permanent stuff (S3, DynamoDB, budget alarm) costs pennies. NAT gateway is the
biggest hourly cost — that's why `make down` matters.

## State file recovery

There is one state file (`terraform.tfstate`), overwritten each apply. S3
versioning keeps every previous version behind the scenes.

If the state file gets corrupted:

1. **Roll back** — find the last good version by timestamp in the S3 console,
   download it, re-upload it as the current version.
2. **`terraform plan`** — shows the gap between your `.tf` files and the
   restored receipt.
3. **`terraform import`** — for each missing resource, tell Terraform its AWS
   ID to add it back to the state file.
4. **`terraform plan` again** — should say "nothing to do." Back in sync.

Never manually edit the state file. `terraform import` is the safe way.
