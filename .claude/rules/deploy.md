---
paths:
  - "deploy/**"
  - "tools/**"
---

# The list, its checks and the deployment

The deployment's list is `deploy/production.json`, by its schema `deploy/schema/production.schema.json`, beside `deploy/production/deployment.json` and `deploy/production/facts.json`, and a self-hosted copy's own legal texts, `deploy/production/legal/`, which the deployment lays over `api`'s image; the platform has none. Its checks are `tools/deploy-check/`, and the deployment by it is `tools/deploy/` — `api.sh` for `api`, `app.mjs` for `app`'s build, `target.mjs` for the workflow — on Node.js, with one `tools/package.json` and its lock file. `tools/organizer/organizer.mjs` is the organizer's tool for the operator's bucket — the upload link and the Custom-Time —, which runs where `gcloud` is signed in as the organizer, on Node.js alone, with no package. Code of `tools/` comes with its tests.

- `just deploy-check origin/main` runs the checks of a pull request that changes the list: the list by its schema, the files of its releases by `release-verify` and sha256, `deployment.json`, the facts by spec's admission table, the rung against `api_admission_rung` of the configuration and `full` wherever the facts name a category under 18, `api` at its service's address, `api`'s tag no lower than at base, and a copy's folder of legal texts by spec's `legal-check-dir`. It reads the releases from GitHub and Sigstore. CI runs it as `just ci-deploy-check origin/main`, only when the pull request changes what the list is checked or deployed by, the tag of spec among it.
- Their tests run with no network: `just deploy-check-test`, `just deploy-api-test`, `just deploy-app-test`, `just deploy-target-test`, `just tools-install-test` and `just organizer-test`; `just deploy-check-release-test` checks a real release of `api` against GitHub and Sigstore.
- `just ci-licenses` checks the licenses of `tools/package-lock.json` by spec's check; a task that changes `tools/package.json` or the lock file ends with it green.
- The scripts `tools/deploy/*.sh` and `tools/ci/*.sh` are checked by `just ci-shellcheck`, which CI runs in the job OpenTofu.

A task that touches `deploy/` or `tools/` ends with the tests of what it touched green, and with `just deploy-check origin/main` when it touches the list or what checks it. CI runs the rest in the job Deploy, in the `toolchain-core` stage, which holds none of OpenTofu's tools, where `ci-deploy-check` checks the list only when the paths it names change.
