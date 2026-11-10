# infra's own recipes. spec's, the documents check among them, run from spec's justfile:
# `just -f spec/justfile docs-check-repo`. CI runs the ci- recipes, tf-check, bootstrap-test and the
# tests of deploy-check in the toolchain stage of .devcontainer/Dockerfile, through
# spec/tools/toolchain/toolchain.sh (R30 spec): the jobs OpenTofu, required in the ruleset of main,
# and Deploy.

# The Dockerfile whose ARGs ci-tofu and ci-shellcheck read; their tests point it at broken copies.
dockerfile := env("INFRA_DOCKERFILE", ".devcontainer/Dockerfile")

# One ARG of the Dockerfile, as Docker reads it — quotes, a carriage return and trailing blanks are
# not part of it — and only if it is one exact version: what ci-tofu, ci-shellcheck and ci-actionlint
# hold their tool to.
_arg name:
    #!/usr/bin/env bash
    set -euo pipefail
    value=$(sed -n 's/^ARG {{ name }}=//p' {{ quote(dockerfile) }} | tr -d '"\r' | sed 's/[[:space:]]*$//')
    if ! [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "{{ dockerfile }} names no single exact ARG {{ name }}" >&2
        exit 1
    fi
    echo "$value"

# The OpenTofu on PATH is the one the toolchain stage installs, at the version its ARG names (R09).
# In the devcontainer it stops a container not rebuilt since the ARG was raised. In CI, where the
# stage is built from the same Dockerfile, it says that the stage installed tofu and that tofu runs;
# the module's checks join it in the same job (T12).
ci-tofu:
    #!/usr/bin/env bash
    set -euo pipefail
    # The value as Docker reads it: quotes, a carriage return and trailing blanks are not part of it.
    want=$({{ quote(just_executable()) }} -f {{ quote(justfile()) }} _arg OPENTOFU_VERSION)
    if ! command -v tofu >/dev/null; then
        echo "ci-tofu: no tofu on PATH: the toolchain stage installs it, at ${want}" >&2
        exit 1
    fi
    # tofu version -json names its own version in the field Terraform gave it.
    got=$(tofu version -json | node -e '
        let text = "";
        process.stdin.on("data", (chunk) => { text += chunk; });
        process.stdin.on("end", () => {
            let version = "";
            try { version = String(JSON.parse(text).terraform_version ?? ""); } catch {}
            process.stdout.write(version);
        });
    ')
    if [ "$got" != "$want" ]; then
        echo "ci-tofu: tofu is ${got:-of no version}, and {{dockerfile}} names ${want}" >&2
        exit 1
    fi
    echo "ci-tofu: OpenTofu ${got}"

# ci-tofu's own test, with no real tofu: a stand-in tofu ahead on PATH, and copies of the Dockerfile
# with its ARG broken. Every refusal must name its reason; the right version must pass.
ci-tofu-test:
    #!/usr/bin/env bash
    set -euo pipefail
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/bin" "$work/empty"
    want=$(sed -n 's/^ARG OPENTOFU_VERSION=//p' {{quote(dockerfile)}})
    just={{quote(just_executable())}}
    stub() {
    cat > "$work/bin/tofu" <<EOF
    #!/bin/sh
    echo '$1'
    EOF
        chmod +x "$work/bin/tofu"
    }
    # refuses <reason> <command>...: the command fails and its output holds the reason.
    refuses() {
        local reason="$1"; shift
        if "$@" >"$work/out" 2>&1; then
            echo "ci-tofu-test: ci-tofu passed where it must refuse: ${reason}" >&2; exit 1
        fi
        grep -qF "$reason" "$work/out" || { echo "ci-tofu-test: the refusal does not say \"${reason}\":" >&2; cat "$work/out" >&2; exit 1; }
    }
    stub '{"terraform_version": "0.0.1"}'
    refuses "tofu is 0.0.1" env PATH="$work/bin:$PATH" "$just" ci-tofu
    stub '{"platform": "linux_amd64"}'
    refuses "tofu is of no version" env PATH="$work/bin:$PATH" "$just" ci-tofu
    stub 'not json'
    refuses "tofu is of no version" env PATH="$work/bin:$PATH" "$just" ci-tofu
    # No tofu at all: only the directories of bash, sed and node, with none of tofu's.
    refuses "no tofu on PATH" env PATH="$work/empty:/usr/bin:/bin:$(dirname "$(command -v node)")" "$just" ci-tofu
    sed '/^ARG OPENTOFU_VERSION=/d' {{quote(dockerfile)}} > "$work/none"
    refuses "names no single exact ARG" env INFRA_DOCKERFILE="$work/none" PATH="$work/bin:$PATH" "$just" ci-tofu
    sed 's/^ARG OPENTOFU_VERSION=.*/ARG OPENTOFU_VERSION=latest/' {{quote(dockerfile)}} > "$work/latest"
    refuses "names no single exact ARG" env INFRA_DOCKERFILE="$work/latest" PATH="$work/bin:$PATH" "$just" ci-tofu
    # A quoted value with a carriage return is the same version, as Docker reads it.
    sed "s/^ARG OPENTOFU_VERSION=.*/ARG OPENTOFU_VERSION=\"${want}\"\r/" {{quote(dockerfile)}} > "$work/quoted"
    stub "{\"terraform_version\": \"${want}\"}"
    env INFRA_DOCKERFILE="$work/quoted" PATH="$work/bin:$PATH" "$just" ci-tofu >"$work/out" 2>&1 || { echo "ci-tofu-test: ci-tofu refused a quoted ARG of ${want}:" >&2; cat "$work/out" >&2; exit 1; }
    env PATH="$work/bin:$PATH" "$just" ci-tofu >"$work/out" 2>&1 || { echo "ci-tofu-test: ci-tofu refused tofu ${want}:" >&2; cat "$work/out" >&2; exit 1; }
    echo "ci-tofu-test: ok"

# ShellCheck over the repository's scripts — tofu/bootstrap.sh, tools/deploy/*.sh and tools/ci/*.sh — by the
# ShellCheck the toolchain stage installs, at the version its ARG names (the 2026-11-09 amendment to
# R09).
ci-shellcheck:
    #!/usr/bin/env bash
    set -euo pipefail
    want=$({{ quote(just_executable()) }} -f {{ quote(justfile()) }} _arg SHELLCHECK_VERSION)
    if ! command -v shellcheck >/dev/null; then
        echo "ci-shellcheck: no shellcheck on PATH: the toolchain stage installs it, at ${want}" >&2
        exit 1
    fi
    got=$(shellcheck --version | sed -n 's/^version: //p')
    if [ "$got" != "$want" ]; then
        echo "ci-shellcheck: shellcheck is ${got:-of no version}, and {{dockerfile}} names ${want}" >&2
        exit 1
    fi
    shellcheck {{ quote(tofu_dir) }}/bootstrap.sh tools/deploy/*.sh tools/ci/*.sh
    echo "ci-shellcheck: ShellCheck ${got}, {{ tofu_dir }}/bootstrap.sh, tools/deploy/*.sh and tools/ci/*.sh clean"

# ci-shellcheck's own test, with no real shellcheck: a stand-in ahead on PATH, of another version,
# of none and of the right one, which finds a script clean or not as it is told.
ci-shellcheck-test:
    #!/usr/bin/env bash
    set -euo pipefail
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/bin"
    want=$(sed -n 's/^ARG SHELLCHECK_VERSION=//p' {{quote(dockerfile)}})
    just={{quote(just_executable())}}
    stub() {
    cat > "$work/bin/shellcheck" <<EOF
    #!/bin/sh
    if [ "\$1" = --version ]; then printf '%s\n' 'ShellCheck - shell script analysis tool' '$1'; exit 0; fi
    echo "In \$1 line 1: SC2086"
    exit ${2:-0}
    EOF
        chmod +x "$work/bin/shellcheck"
    }
    refuses() {
        local reason="$1"; shift
        if "$@" >"$work/out" 2>&1; then
            echo "ci-shellcheck-test: ci-shellcheck passed where it must refuse: ${reason}" >&2; exit 1
        fi
        grep -qF "$reason" "$work/out" || { echo "ci-shellcheck-test: the refusal does not say \"${reason}\":" >&2; cat "$work/out" >&2; exit 1; }
    }
    stub 'version: 0.0.1'
    refuses "shellcheck is 0.0.1" env PATH="$work/bin:$PATH" "$just" ci-shellcheck
    stub 'license: none'
    refuses "shellcheck is of no version" env PATH="$work/bin:$PATH" "$just" ci-shellcheck
    stub "version: ${want}" 1
    refuses "SC2086" env PATH="$work/bin:$PATH" "$just" ci-shellcheck
    sed 's/^ARG SHELLCHECK_VERSION=.*/ARG SHELLCHECK_VERSION=latest/' {{quote(dockerfile)}} > "$work/latest"
    refuses "names no single exact ARG" env INFRA_DOCKERFILE="$work/latest" PATH="$work/bin:$PATH" "$just" ci-shellcheck
    stub "version: ${want}"
    env PATH="$work/bin:$PATH" "$just" ci-shellcheck >"$work/out" 2>&1 || { echo "ci-shellcheck-test: ci-shellcheck refused shellcheck ${want}:" >&2; cat "$work/out" >&2; exit 1; }
    echo "ci-shellcheck-test: ok"

# actionlint over the workflows, .github/workflows, by the actionlint the toolchain stage installs, at
# the version its ARG names, with the stage's ShellCheck for their scripts (the second 2026-11-09
# amendment to R09). The deployment's workflow runs only after a merge, so this is where its mistakes
# show before one (R18).
ci-actionlint:
    #!/usr/bin/env bash
    set -euo pipefail
    want=$({{ quote(just_executable()) }} -f {{ quote(justfile()) }} _arg ACTIONLINT_VERSION)
    if ! command -v actionlint >/dev/null; then
        echo "ci-actionlint: no actionlint on PATH: the toolchain stage installs it, at ${want}" >&2
        exit 1
    fi
    got=$(actionlint -version | head -n 1)
    if [ "$got" != "$want" ]; then
        echo "ci-actionlint: actionlint is ${got:-of no version}, and {{dockerfile}} names ${want}" >&2
        exit 1
    fi
    # Without ShellCheck actionlint would skip the workflows' scripts and still say clean.
    if ! shellcheck="$(command -v shellcheck)"; then
        echo "ci-actionlint: no shellcheck on PATH: the toolchain stage installs it, and actionlint checks the workflows' scripts with it" >&2
        exit 1
    fi
    actionlint -shellcheck="$shellcheck"
    echo "ci-actionlint: actionlint ${got}, .github/workflows clean"

# ci-actionlint's own test, with no real actionlint: a stand-in ahead on PATH, of another version,
# of none and of the right one, which finds the workflows clean or not as it is told.
ci-actionlint-test:
    #!/usr/bin/env bash
    set -euo pipefail
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    mkdir "$work/bin"
    want=$(sed -n 's/^ARG ACTIONLINT_VERSION=//p' {{quote(dockerfile)}})
    just={{quote(just_executable())}}
    stub() {
    cat > "$work/bin/actionlint" <<STUB
    #!/bin/sh
    if [ "\$1" = -version ]; then printf '%s\n' '$1' 'installed by downloading from release page'; exit 0; fi
    echo ".github/workflows/deploy.yml:1:1: unexpected key [syntax-check]"
    exit ${2:-0}
    STUB
        chmod +x "$work/bin/actionlint"
    }
    refuses() {
        local reason="$1"; shift
        if "$@" >"$work/out" 2>&1; then
            echo "ci-actionlint-test: ci-actionlint passed where it must refuse: ${reason}" >&2; exit 1
        fi
        grep -qF "$reason" "$work/out" || { echo "ci-actionlint-test: the refusal does not say \"${reason}\":" >&2; cat "$work/out" >&2; exit 1; }
    }
    stub '0.0.1'
    refuses "actionlint is 0.0.1" env PATH="$work/bin:$PATH" "$just" ci-actionlint
    stub ''
    refuses "actionlint is of no version" env PATH="$work/bin:$PATH" "$just" ci-actionlint
    stub "${want}" 1
    refuses "syntax-check" env PATH="$work/bin:$PATH" "$just" ci-actionlint
    sed 's/^ARG ACTIONLINT_VERSION=.*/ARG ACTIONLINT_VERSION=latest/' {{quote(dockerfile)}} > "$work/latest"
    refuses "names no single exact ARG" env INFRA_DOCKERFILE="$work/latest" PATH="$work/bin:$PATH" "$just" ci-actionlint
    stub "${want}"
    env PATH="$work/bin:$PATH" "$just" ci-actionlint >"$work/out" 2>&1 || { echo "ci-actionlint-test: ci-actionlint refused actionlint ${want}:" >&2; cat "$work/out" >&2; exit 1; }
    echo "ci-actionlint-test: ok"

# The root module in tofu/, by the OpenTofu of the toolchain stage (R10).
tofu_dir := "tofu"

# Format the module in place.
tf-fmt:
    tofu -chdir={{ tofu_dir }} fmt -recursive

# What CI runs on the module: its format, an init with no backend that installs the providers by
# the lock file and refuses one the lock file does not name, a validate, and the tests, which run
# against mock providers and need no credential.
tf-check: _tf-sinks _tf-grants _tf-roles _tf-test-values
    tofu -chdir={{ tofu_dir }} fmt -check -recursive -diff
    tofu -chdir={{ tofu_dir }} init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{ tofu_dir }} validate
    tofu -chdir={{ tofu_dir }} test

# Every log sink is declared in the one list of tofu/logging.tf, google_logging_project_sink.sinks,
# so that each gets the exclusions R07 asks for and the tests hold each to them: a sink declared
# anywhere else would pass them by.
_tf-sinks:
    #!/usr/bin/env bash
    set -euo pipefail
    stray=$(grep -rnE '^[[:space:]]*resource[[:space:]]+"google_(logging_(project|folder|organization|billing_account)_sink|logging_project_exclusion)"' {{ quote(tofu_dir) }} --include='*.tf' | grep -vE ':[[:space:]]*resource[[:space:]]+"google_logging_project_sink"[[:space:]]+"sinks"[[:space:]]*\{' || true)
    if [ -n "$stray" ]; then
        echo "tf-check: a log sink or exclusion outside google_logging_project_sink.sinks in tofu/logging.tf (R07):" >&2
        echo "$stray" >&2
        exit 1
    fi

# Every grant on the project is in the one list of tofu/identities.tf, google_project_iam_member.grants,
# so that the test holds each against the roles bootstrap.sh's condition lets the configuration's
# identity grant there (R13): a grant declared anywhere else would pass it by and be refused at the
# apply, after the merge.
_tf-grants:
    #!/usr/bin/env bash
    set -euo pipefail
    stray=$(grep -rnE '^[[:space:]]*resource[[:space:]]+"google_project_iam_(member|binding|policy)"' {{ quote(tofu_dir) }} --include='*.tf' | grep -vE ':[[:space:]]*resource[[:space:]]+"google_project_iam_member"[[:space:]]+"grants"[[:space:]]*\{' || true)
    if [ -n "$stray" ]; then
        echo "tf-check: a grant on the project outside google_project_iam_member.grants in tofu/identities.tf (R13):" >&2
        echo "$stray" >&2
        exit 1
    fi

# Every variable of the configuration is set in tofu/tests/terraform.tfvars: tofu test reads the
# deployment's tofu/production.auto.tfvars too, and a variable this file leaves out would take the
# deployment's value into every test (T30).
_tf-test-values:
    #!/usr/bin/env bash
    set -euo pipefail
    declared=$(sed -n 's/^variable "\([a-z0-9_]*\)".*/\1/p' {{ quote(tofu_dir) }}/*.tf | sort -u)
    set_in_tests=$(sed -n 's/^\([a-z0-9_]*\)[[:space:]]*=.*/\1/p' {{ quote(tofu_dir) }}/tests/terraform.tfvars | sort -u)
    missing=$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$set_in_tests"))
    if [ -n "$missing" ]; then
        echo "tf-check: tofu/tests/terraform.tfvars does not set these variables, so a deployment's values would reach the tests:" >&2
        echo "$missing" >&2
        exit 1
    fi

# Every type of resource and data in tofu/*.tf is named by a role that bootstrap.sh gives the
# identity the configuration is applied as, and every type a role names is still there (R13): a type
# no role is held for would pass every other check and be refused at the apply, after the merge.
_tf-roles:
    #!/usr/bin/env bash
    set -euo pipefail
    used=$(grep -hoE '^[[:space:]]*(resource|data)[[:space:]]+"[a-z0-9_]+"' {{ quote(tofu_dir) }}/*.tf | tr -d '"' | awk '{ print ($1 == "data" ? "data." : "") $2 }' | sort -u)
    named=$(grep -oE '^[[:space:]]*"roles/[A-Za-z.]+( [a-z0-9_.]+)*"$' {{ quote(tofu_dir) }}/bootstrap.sh | tr -d '"' | awk '{ for (i = 2; i <= NF; i++) print $i }' | sort -u)
    missing=$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$named"))
    stale=$(comm -13 <(printf '%s\n' "$used") <(printf '%s\n' "$named"))
    if [ -n "$missing" ]; then
        echo "tf-check: no role in {{ tofu_dir }}/bootstrap.sh is held for these types of {{ tofu_dir }}/ (R13):" >&2
        echo "$missing" >&2
        exit 1
    fi
    if [ -n "$stale" ]; then
        echo "tf-check: {{ tofu_dir }}/bootstrap.sh names types {{ tofu_dir }}/ no longer has (R13):" >&2
        echo "$stale" >&2
        exit 1
    fi

# Run once, by someone who may make projects and link them to the billing account, with
# TF_VAR_billing_account set and tofu/production.auto.tfvars and tofu/backend.hcl filled in; again
# whenever the script changes, before the merge that needs it (R13).
# Make the project, its state bucket, the federated pool and the identity CI applies the configuration as
bootstrap:
    bash {{ quote(tofu_dir) }}/bootstrap.sh

# bootstrap.sh against a stand-in gcloud, with synthetic values: no cloud, no credential.
bootstrap-test:
    node --test {{ quote(tofu_dir) }}/tests/bootstrap.test.mjs

# The tools of tools/, by its lock file: installed again only when package.json or the lock file
# changes, as spec's own _tools does.
_tools:
    #!/usr/bin/env bash
    set -euo pipefail
    stamp=tools/node_modules/.installed-from
    wanted="$(cd tools && sha256sum package.json package-lock.json)"
    if [[ ! -f "$stamp" || "$(cat "$stamp")" != "$wanted" ]]; then
        (cd tools && npm ci --ignore-scripts --no-audit --no-fund)
        printf '%s\n' "$wanted" > "$stamp"
    fi

# The packages of tools/package-lock.json against the licenses NovaTrail builds from, by spec's check
# (R12 spec).
ci-licenses:
    just -f spec/justfile licenses-check-repo tools/package-lock.json

# The checks R05 asks of a pull request that changes the deployment's list (R14): deploy/production.json
# by its schema, the files of its releases by release-verify and sha256, deployment.json, the facts,
# the rung, and api's tag no lower than in the list at base. It reads the releases from GitHub and
# Sigstore. With no list yet there is nothing to check, and it says so.
# Check the deployment's list in deploy/ against the list at base
deploy-check base="origin/main": _tools
    node tools/deploy-check/main.mjs --base {{ quote(base) }} deploy

# What CI runs: deploy-check, when the pull request changes against base what the list is checked
# or deployed by — deploy/, the checks, the deployment of tools/deploy/, their packages, this file,
# or the tag of spec, whose admission table and release-verify the checks read — and otherwise
# nothing, so that a pull request of documents downloads no release.
ci-deploy-check base="origin/main":
    #!/usr/bin/env bash
    set -euo pipefail
    base={{ quote(base) }}
    if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
        echo "ci-deploy-check: the base ${base} is not a commit here: fetch it before the check" >&2
        exit 1
    fi
    changed=$(git diff --name-only "${base}...HEAD" -- deploy tools/deploy-check tools/deploy tools/package.json tools/package-lock.json justfile spec)
    if [ -z "$changed" ]; then
        echo "ci-deploy-check: nothing the list is checked by changes against ${base}, and the list is not checked"
        exit 0
    fi
    just deploy-check "$base"

# The checks' own tests, on synthetic releases, with no network, and the reading of
# /deployment.json on spec's vectors of reading.
deploy-check-test: _tools
    node --test tools/deploy-check/test/check.test.mjs tools/deploy-check/test/reading.test.mjs

# The check of a release's files on a real release of api, against GitHub and Sigstore (R14).
deploy-check-release-test: _tools
    node --test tools/deploy-check/test/release.test.mjs

# api's deployment by the list, as R05 lays out its steps (R15), on what the configuration's outputs
# name, as `tofu output -json` prints them after the apply of the same commit; a relative path to them
# is the caller's, from where just is run. They run gcloud and docker, signed in as api's deployment.
# Build api's image of the list's release, push it and print its digest
deploy-api-image outputs: _tools
    cd {{ quote(invocation_directory()) }} && {{ quote(justfile_directory() / "tools/deploy/api.sh") }} image {{ quote(outputs) }} {{ quote(justfile_directory() / "deploy") }}

# Deploy the list's release of api: image, jobs, revision and traffic
deploy-api outputs: _tools
    cd {{ quote(invocation_directory()) }} && {{ quote(justfile_directory() / "tools/deploy/api.sh") }} release {{ quote(outputs) }} {{ quote(justfile_directory() / "deploy") }}

# Give api's service a new version of the facts, on the image that takes the traffic
deploy-api-facts outputs:
    cd {{ quote(invocation_directory()) }} && {{ quote(justfile_directory() / "tools/deploy/api.sh") }} facts {{ quote(outputs) }} {{ quote(justfile_directory() / "deploy") }}

# tools/deploy/api.sh against stand-ins for gcloud, docker and fetch.mjs: no cloud, no network.
deploy-api-test:
    node --test tools/deploy/test/api.test.mjs

# The release of app's build on Firebase Hosting by the list, as R06 lays out its steps (R17), on
# the site the configuration's outputs name. It signs in with an access token gcloud gives for the
# identity it is signed in as, hosting-publish where the workflow runs it, and the token goes to the
# script through its environment, never its command line.
# Release the list's build of app on Hosting, with the assets of the build released, and check it
deploy-app outputs: _tools
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{ quote(invocation_directory()) }}
    HOSTING_ACCESS_TOKEN="$(gcloud auth print-access-token)"
    export HOSTING_ACCESS_TOKEN
    node {{ quote(justfile_directory() / "tools/deploy/app.mjs") }} release {{ quote(outputs) }} {{ quote(justfile_directory() / "deploy") }}

# Check what the site answers against the list's build of app
deploy-app-check outputs: _tools
    cd {{ quote(invocation_directory()) }} && node {{ quote(justfile_directory() / "tools/deploy/app.mjs") }} check {{ quote(outputs) }} {{ quote(justfile_directory() / "deploy") }}

# tools/deploy/app.mjs against a stand-in for Hosting's API, synthetic releases of app and a
# stand-in for the site: no cloud, no network.
deploy-app-test: _tools
    node --test tools/deploy/test/app.test.mjs

# The workflow of the deployment, .github/workflows/deploy.yml, runs these (R18); each also runs
# by hand, where the repository is checked out with its origin.
# What a run delivers, as key=value lines for $GITHUB_OUTPUT: given --by-hand=<parts>, the parts a
# run started by hand names
ci-deploy-target commit flag="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n {{ quote(flag) }} ]; then
        node tools/deploy/target.mjs target {{ quote(commit) }} {{ quote(flag) }}
    else
        node tools/deploy/target.mjs target {{ quote(commit) }}
    fi

# Whether main still stands on the commit, before a job run again deploys it
ci-deploy-current commit:
    node tools/deploy/target.mjs current {{ quote(commit) }}

# The provider of the federated pool and the configuration's identity, from tofu/ci.env
ci-deploy-identity:
    node tools/deploy/target.mjs identity

# The GitHub environments the configuration lends its identities to, each there and run from main
# alone, by GitHub's API (R18).
ci-deploy-environments +names:
    node tools/deploy/target.mjs environments {{ names }}

# The configuration applied, by the lock file and the backend of the deployment, with the billing
# account and the operator's address kept out of what it prints: the budget's name holds the first,
# and a refresh prints it (canvas-api).
ci-tf-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    redact() {
        local line
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -n "${TF_VAR_billing_account:-}" ]; then line="${line//"$TF_VAR_billing_account"/<billing account>}"; fi
            if [ -n "${TF_VAR_operator_email:-}" ]; then line="${line//"$TF_VAR_operator_email"/<operator email>}"; fi
            printf '%s\n' "$line"
        done
    }
    tofu -chdir={{ quote(tofu_dir) }} init -backend-config=backend.hcl -input=false -lockfile=readonly -no-color 2>&1 | redact
    tofu -chdir={{ quote(tofu_dir) }} apply -auto-approve -input=false -no-color -lock-timeout=5m 2>&1 | redact

# The configuration's outputs into a file, as `tofu output -json` prints them, for the recipes of the
# deployment, and the two identities the later jobs sign in as, for $GITHUB_OUTPUT
ci-tf-outputs out:
    #!/usr/bin/env bash
    set -euo pipefail
    out={{ quote(out) }}
    tofu -chdir={{ quote(tofu_dir) }} output -json > "$out"
    deploy="$(jq -er '.deploy_service_account.value' "$out")"
    hosting="$(jq -er '.hosting_service_account.value' "$out")"
    echo "deploy_service_account=${deploy}"
    echo "hosting_service_account=${hosting}"
    echo "deploy_environment=$(jq -er '.deploy_environment.value' "$out")"
    echo "hosting_environment=$(jq -er '.hosting_environment.value' "$out")"

# tools/deploy/target.mjs against repositories made here and a stand-in for GitHub's API, and the
# workflow's own shape: no network.
deploy-target-test:
    node --test tools/deploy/test/target.test.mjs

# tools/ci/install.sh against stand-ins for curl and docker: no network.
tools-install-test:
    node --test tools/ci/test/install.test.mjs
