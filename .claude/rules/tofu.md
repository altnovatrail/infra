---
paths:
  - "tofu/**"
---

# The configuration in `tofu/`

The root module in `tofu/` describes the platform's project in OpenTofu (R10), and `tofu/bootstrap.sh` makes the project, its state bucket, the federated pool and the identity the configuration is applied as, once, with the operator's own rights (R13), and the operator's two buckets with all their access (R28): the addresses of the people who hold them come from `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER` and `BOOTSTRAP_OPERATOR`, never from a file.

`just tf-check` is what CI runs on the module: its format, an init with no backend that installs the providers by the lock file, a validate, and the tests, which run on mock providers with `tofu/tests/terraform.tfvars` and need no credential (R10). Before them it holds four lists: every log sink in the one list of `tofu/logging.tf` (R07), every grant on the project in the one list of `tofu/identities.tf`, every type of resource and data named by a role `bootstrap.sh` gives (R13), and every variable set in `tofu/tests/terraform.tfvars`, a variable with a default set to `null` (the 2026-11-12 amendment to R10). `just tf-fmt` formats the module in place. `tofu/bootstrap.sh` is checked by `just ci-shellcheck` and by `just bootstrap-test`, against a stand-in `gcloud` with synthetic values; a change to it runs again by the operator before the merge that needs it (R13).

A task that touches `tofu/` ends with `just tf-check` green, and one that touches `bootstrap.sh` with `ci-shellcheck` and `bootstrap-test` too; CI runs them in the job OpenTofu, in the `toolchain` stage, through `spec/tools/toolchain/toolchain.sh`. A change to `tofu/variables.tf` also runs the list's checks, `just deploy-check origin/main`: its default names `api`'s service (the second 2026-11-12 amendment to R14). So does a change to `tofu/production.auto.tfvars` or `tofu/ci.env`, which give the service's region, name and project number, but CI does not run the checks for them — a fork's first pull request changes them alone — so the task runs them by hand.

A change that moves where learners' data are or what opens them — a store, a secret, an account or its right, a log or its exclusion — edits part 1 of [BREACH.md](../../BREACH.md) in the same change: its table of where the data are, how to cut the access and what the logs show (R27).
