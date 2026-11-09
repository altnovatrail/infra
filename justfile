# infra's own recipes. spec's, the documents check among them, run from spec's justfile:
# `just -f spec/justfile docs-check-repo`. CI runs the ci- recipes and tf-check in the toolchain
# stage of .devcontainer/Dockerfile, through spec/tools/toolchain/toolchain.sh (R30 spec): the job
# OpenTofu, required in the ruleset of main.

# The Dockerfile whose ARG ci-tofu reads; ci-tofu-test points it at broken copies.
dockerfile := env("INFRA_DOCKERFILE", ".devcontainer/Dockerfile")

# The OpenTofu on PATH is the one the toolchain stage installs, at the version its ARG names (R09).
# In the devcontainer it stops a container not rebuilt since the ARG was raised. In CI, where the
# stage is built from the same Dockerfile, it says that the stage installed tofu and that tofu runs;
# the module's checks join it in the same job (T12).
ci-tofu:
    #!/usr/bin/env bash
    set -euo pipefail
    # The value as Docker reads it: quotes, a carriage return and trailing blanks are not part of it.
    want=$(sed -n 's/^ARG OPENTOFU_VERSION=//p' {{quote(dockerfile)}} | tr -d '"\r' | sed 's/[[:space:]]*$//')
    if ! [[ "$want" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ci-tofu: {{dockerfile}} names no single exact ARG OPENTOFU_VERSION" >&2
        exit 1
    fi
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

# The root module in tofu/, by the OpenTofu of the toolchain stage (R10).
tofu_dir := "tofu"

# Format the module in place.
tf-fmt:
    tofu -chdir={{ tofu_dir }} fmt -recursive

# What CI runs on the module: its format, an init with no backend that installs the providers by
# the lock file and refuses one the lock file does not name, a validate, and the tests, which run
# against mock providers and need no credential.
tf-check:
    tofu -chdir={{ tofu_dir }} fmt -check -recursive -diff
    tofu -chdir={{ tofu_dir }} init -backend=false -input=false -lockfile=readonly
    tofu -chdir={{ tofu_dir }} validate
    tofu -chdir={{ tofu_dir }} test
