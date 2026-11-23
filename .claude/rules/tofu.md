---
paths:
  - "tofu/**"
---

# The configuration in `tofu/`

The root module in `tofu/` describes the platform's project in OpenTofu, and `tofu/bootstrap.sh` makes the project, its state bucket, the federated pool and the identity the configuration is applied as, once, with the operator's own rights, and the operator's two buckets with all their access (R28): the addresses of the people who hold them come from `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER` and `BOOTSTRAP_OPERATOR`, never from a file.

`just tf-check` is what CI runs on the module: its format, an init with no backend that installs the providers by the lock file, a validate, and the tests, which run on mock providers with `tofu/tests/terraform.tfvars` and need no credential. Before them it holds five lists (R10): every log sink in the one list of `tofu/logging.tf` (R07), every grant on the project in the one list of `tofu/identities.tf`, every type of resource and data named by a role `bootstrap.sh` gives (R13), every variable set in `tofu/tests/terraform.tfvars`, a variable with a default set to `null`, and every resource, data source and output of the module in the list of the copy's test, `tofu/tests/copy.tftest.hcl`, and nothing else there. `just tf-fmt` formats the module in place. `tofu/bootstrap.sh` is checked by `just ci-shellcheck` and by `just bootstrap-test`, against a stand-in `gcloud` with synthetic values; a change to it runs again by the operator before the merge that needs it (R13).

A task that touches `tofu/` ends with `just tf-check` green, and one that touches `bootstrap.sh` with `ci-shellcheck` and `bootstrap-test` too; CI runs them in the job OpenTofu, in the `toolchain` stage, which adds OpenTofu, ShellCheck and actionlint to the core (R34), through `spec/tools/toolchain/toolchain.sh`. A change to `tofu/variables.tf` also runs the list's checks, `just deploy-check origin/main`: its default names `api`'s service (R14). So does a change to `tofu/production.auto.tfvars` or `tofu/ci.env`, which give the service's region, name and project number, but CI does not run the checks for them — a fork's first pull request changes them alone — so the task runs them by hand; CI runs them for the line `api_admission_rung` of the values, which the list's rung is held to.

A change that moves where learners' data are or what opens them — a store, a secret, an account or its right, a log or its exclusion — edits part 1 of [BREACH.md](../../BREACH.md) in the same change: its table of where the data are, how to cut the access and what the logs show (R27).
