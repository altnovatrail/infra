---
paths:
  - ".github/**"
  - ".devcontainer/**"
  - "justfile"
---

# CI, the workflows and the container

CI, `.github/workflows/ci.yml`, runs the checks every NovaTrail repository shares — Secrets, DCO and Documents, from `.github`'s shared workflows pinned by SHA, with CodeQL and Scorecard in workflows of their own — and infra's own: the jobs OpenTofu, required in the ruleset of `main`, Deploy and Deployment tools. The job Toolchain image and the jobs OpenTofu and Deploy, which need it, take their stage through `.github/actions/toolchain`, by its input `stage`: OpenTofu `toolchain`, Deploy `toolchain-core`, whose cache entry the shared Documents check keeps too. On a miss Toolchain image alone builds each stage, the core first, and hands its file to the job that takes it as an artifact of the run — if its build or upload fails, that job builds its own —, and only a push to `main` saves an entry. `.github/workflows/deploy.yml` is the deployment's workflow: it runs only after a merge, so `just ci-actionlint` is where its mistakes show before one. The recipes are in the `justfile`, and `just --list` names them.

The container is spec's, and differs from it by three tools in the `toolchain` stage of `.devcontainer/Dockerfile`, each at an exact version and its sums: OpenTofu, ShellCheck and actionlint. The stage is `FROM toolchain-core`, the template's core word for word, and adds them by a `RUN` of its own; the core holds none of them. A move to a new tag of spec keeps them there. `just ci-tofu`, `just ci-shellcheck` and `just ci-actionlint` hold each tool to the version its `ARG` names, and `ci-tofu-test`, `ci-shellcheck-test` and `ci-actionlint-test` test them on broken copies of the Dockerfile. A raised `ARG` takes a Rebuild Container, a step of the author's. `.github/actions/tools` and `tools/ci/install.sh` install the deployment's tools on a runner, and the job Deployment tools checks them when the pull request changes them.

actionlint reads `.github/workflows` and checks a local action's inputs where a workflow calls it, but not the steps of `.github/actions/`: a change there shows in the pull request's run of the jobs that call it. A task that touches `.github/` ends with `ci-actionlint` green; one that touches the Dockerfile, with the recipe and the test of the tool it changed; one that touches the `justfile`, with the tests of the recipes it changed.
