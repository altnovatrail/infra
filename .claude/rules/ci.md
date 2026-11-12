---
paths:
  - ".github/**"
  - ".devcontainer/**"
  - "justfile"
---

# CI, the workflows and the container

CI, `.github/workflows/ci.yml`, runs the checks every NovaTrail repository shares — Secrets, DCO and Documents, from `.github`'s shared workflows pinned by SHA (R30 spec) — and infra's own: the jobs OpenTofu, required in the ruleset of `main`, Deploy and Deployment tools. `.github/workflows/deploy.yml` is the deployment's workflow (R18): it runs only after a merge, so `just ci-actionlint` is where its mistakes show before one. The recipes are in the `justfile`, and `just --list` names them.

The container is spec's, and differs from it by three tools in the `toolchain` stage of `.devcontainer/Dockerfile`, each at an exact version and its sums: OpenTofu, ShellCheck and actionlint (R09 and its 2026-11-09 amendments). A move to a new tag of spec keeps them. `just ci-tofu`, `just ci-shellcheck` and `just ci-actionlint` hold each tool to the version its `ARG` names, and `ci-tofu-test`, `ci-shellcheck-test` and `ci-actionlint-test` test them on broken copies of the Dockerfile. A raised `ARG` takes a Rebuild Container, a step of the author's. `.github/actions/tools` and `tools/ci/install.sh` install the deployment's tools on a runner, and the job Deployment tools checks them when the pull request changes them.

A task that touches `.github/` ends with `ci-actionlint` green; one that touches the Dockerfile, with the recipe and the test of the tool it changed; one that touches the `justfile`, with the tests of the recipes it changed.
