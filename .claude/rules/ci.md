---
paths:
  - ".github/**"
  - ".devcontainer/**"
  - "justfile"
---

# CI, the workflows and the container

CI, `.github/workflows/ci.yml`, runs the checks every NovaTrail repository shares — Secrets, DCO and Documents, from `.github`'s shared workflows pinned by SHA (R30 spec), with CodeQL and Scorecard in workflows of their own — and infra's own: the jobs OpenTofu, required in the ruleset of `main`, Deploy and Deployment tools. The job Toolchain image and the jobs OpenTofu and Deploy, which need it, take the `toolchain` stage through `.github/actions/toolchain`, from the cache entry they share with the shared Documents check: on a miss Toolchain image alone builds it and hands its file to the other two as an artifact of the run — if its build or upload fails, each of the two builds its own —, and only a push to `main` saves the entry (R32 and its second 2026-11-16 amendment). `.github/workflows/deploy.yml` is the deployment's workflow (R18): it runs only after a merge, so `just ci-actionlint` is where its mistakes show before one. The recipes are in the `justfile`, and `just --list` names them.

The container is spec's, and differs from it by three tools in the `toolchain` stage of `.devcontainer/Dockerfile`, each at an exact version and its sums: OpenTofu, ShellCheck and actionlint (R09 and its 2026-11-09 amendments). A move to a new tag of spec keeps them. `just ci-tofu`, `just ci-shellcheck` and `just ci-actionlint` hold each tool to the version its `ARG` names, and `ci-tofu-test`, `ci-shellcheck-test` and `ci-actionlint-test` test them on broken copies of the Dockerfile. A raised `ARG` takes a Rebuild Container, a step of the author's. `.github/actions/tools` and `tools/ci/install.sh` install the deployment's tools on a runner, and the job Deployment tools checks them when the pull request changes them.

actionlint reads `.github/workflows` and checks a local action's inputs where a workflow calls it, but not the steps of `.github/actions/`: a change there shows in the pull request's run of the jobs that call it. A task that touches `.github/` ends with `ci-actionlint` green; one that touches the Dockerfile, with the recipe and the test of the tool it changed; one that touches the `justfile`, with the tests of the recipes it changed.
