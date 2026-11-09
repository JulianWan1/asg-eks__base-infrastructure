# Phase 0 — Notes and learnings

## What Phase 0 is

The infrastructure *for* the infrastructure. It creates the support tools so
Phase 1 and 2 have a safe foundation. You apply it once and leave it alone.

It creates four things:

- **S3 bucket** — stores the state file for Phase 1+
- **DynamoDB lock table** — prevents two Terraform runs from colliding
- **Budget alarm** — emails you when spending approaches $20/month
- **Auto-tagging** — stamps `Project=devops-lab` on every resource

## Scripts vs state — two separate things

- **`.tf` files** (scripts) = the shopping list. What you *want* to exist. Lives
  in your code repo / GitHub.
- **`terraform.tfstate`** (state file) = the receipt. What was *actually* built,
  including AWS IDs and details. Lives in S3 (for Phase 1+) or locally (for
  Phase 0).

Terraform compares the two every time it runs to figure out what needs to
change — create, update, or delete.

## Why Phase 0's state stays local

Phase 0 creates the S3 bucket. You can't store state in a bucket that doesn't
exist yet. That's the chicken-and-egg. So Phase 0 keeps its receipt on your
laptop. Everything after Phase 0 uses the bucket.

## Why Phase 1+ uses S3 (not local)

Same reason you push code to GitHub instead of keeping it only on your laptop:

1. **Shared source of truth.** When CI/CD (GitHub Actions) enters later, both
   your laptop and the pipeline need to see the same receipt.
2. **Can't accidentally lose it.** If you lost the state while a VPC, subnets,
   load balancer, and database all exist in AWS, Terraform forgets they exist.
   You'd have to hunt them down manually.

## How the `.tf` files connect

- **`versions.tf`** — sets minimum requirements (Terraform 1.6+, AWS plugin v6).
- **`variables.tf`** — defines the blanks to fill in (bucket name, email, budget).
- **`terraform.tfvars`** — your actual answers. Linked to `variables.tf` by
  matching names automatically (same name = connected, no imports needed).
- **`providers.tf`** — sets the AWS region and auto-tagging. Reads region from
  variables.
- **`state.tf`** — builds the S3 bucket (with versioning, encryption, no public
  access) and the DynamoDB lock table.
- **`budget.tf`** — builds the $20/month spending alarm.
- **`outputs.tf`** — reads from `state.tf` after everything is built, prints out
  info that Phase 1 needs (bucket name, lock table name, a ready-to-paste
  backend config block).

## DynamoDB locking — the "occupied/vacant" sign

Before Terraform edits the state file, it writes a row to the DynamoDB table
(grabs the lock). When done, it deletes the row (releases the lock). If another
run sees the row, it waits.

- The column is called `LockID` — hardcoded by Terraform, can't rename it.
- Has nothing to do with the app's RDS database — they're completely separate.
- Costs essentially $0 on `PAY_PER_REQUEST`.
- Phase 0 doesn't use it (local state). Phase 1+ will.

## `prevent_destroy`

This is **not** "protect these, delete the rest." If *any* resource has
`prevent_destroy`, Terraform rejects the **entire** destroy. Nothing gets
touched.

To practice applying and destroying Phase 0, remove the `prevent_destroy` blocks
first, then put them back when you're done practicing.

## Destroy order matters

Always destroy in reverse order: Phase 1 first, then Phase 0.

If you delete the S3 bucket while Phase 1's state is still in it, Terraform
loses its receipt and you have to hunt down resources manually in the AWS
console.

## Budget alarm

- Watches your **entire AWS account** spend, not just tagged resources.
- Two alerts: already spent 80% ($16), and *forecasted* to hit 100% ($20).
- The forecast alert is the useful one — catches a NAT gateway left running
  *before* the money is gone.
- It *could* be scoped to just `Project=devops-lab` tagged resources, but that
  requires manually activating the tag as a cost-allocation tag in the AWS
  Billing console (can't be done by Terraform, takes ~24 hours). Account-wide
  is simpler and catches everything.

## Cost estimates (no free tier)

With `make down` discipline at 3 hours/day, 20 days/month (60 hours total):

| Resource | Rate/hour | 60 hours |
|---|---|---|
| NAT gateway | $0.045 | $2.70 |
| EC2 (t3.micro) | $0.012 | $0.72 |
| RDS (db.t4g.micro) | $0.018 | $1.08 |
| Load balancer | $0.023 | $1.38 |
| **Total** | | **~$5.88** |

Permanent stuff (S3, DynamoDB, budget alarm) costs pennies.

NAT gateway is the biggest hourly cost. That's why `make down` matters.

## State file — one file, with version history

- There is **one** state file: `terraform.tfstate`.
- Every time Terraform runs, it overwrites the same file.
- S3 versioning (turned on in `state.tf`) quietly keeps every previous version
  behind the scenes — like Google Docs version history.
- You can see the versions by toggling "Show versions" in the S3 console.

## Recovering from a corrupted state file

If the state file gets corrupted after an apply that added new resources:

1. **Roll back** — in the S3 console, find the last good version by timestamp.
   Download it and re-upload it. It becomes the current version.
2. **`terraform plan`** — shows the gap. "Your instructions say 15 resources,
   my receipt only has 10. I need to create 5."
3. **`terraform import`** — for each missing resource, tell Terraform its AWS
   ID. This adds it to the existing state file (doesn't create a new file).
4. **`terraform plan` again** — should say "nothing to do." Everything is back
   in sync.

Never manually edit the state file in a text editor. `terraform import` is the
safe way to fix gaps.

Note: S3 itself doesn't corrupt files once stored. The realistic threats are
human — accidental deletion, manual edits, or a bad Terraform run. Versioning
covers all of these.

## EOT

Stands for "End Of Text." Just a marker for writing multi-line strings in
Terraform. The word itself doesn't matter — convention only.
