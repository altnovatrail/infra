#!/usr/bin/env bash
# Installs the tools a job of the deployment runs, each at the exact version written down and
# checked against its sha256 before anything unpacks it (R18; RULES.md, Exact versions only):
# OpenTofu, just and Node at the ARGs of .devcontainer/Dockerfile, the versions the container checks
# the repository with, and the Google Cloud CLI, jq and buildx at tools/ci/versions.env. `docker`
# installs nothing: it checks that the runner's Docker engine is the version written down.
#
#   tools/ci/install.sh <dir> <tool>...      tools: tofu just node gcloud jq buildx docker
#
# Everything goes under <dir>, buildx into Docker's plugins of the user; the folders of programs are
# printed, one a line, and added to $GITHUB_PATH when it is set.
#
# INFRA_DOCKERFILE and INFRA_TOOL_VERSIONS are for its test: another Dockerfile and versions file.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dockerfile="${INFRA_DOCKERFILE:-$root/.devcontainer/Dockerfile}"
versions="${INFRA_TOOL_VERSIONS:-$root/tools/ci/versions.env}"

fail() {
    echo "install: $*" >&2
    exit 1
}

[[ $# -ge 2 ]] || fail "usage: install.sh <dir> <tool>..."
dir="$1"
shift
mkdir -p "$dir/bin"
dir="$(cd "$dir" && pwd)"

case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 gnu=x86_64 node_arch=x64 gcloud_arch=x86_64 ;;
    aarch64 | arm64) arch=arm64 gnu=aarch64 node_arch=arm64 gcloud_arch=arm ;;
    *) fail "no tools for the architecture $(uname -m)" ;;
esac
upper="${arch^^}"

# One value: an ARG of the Dockerfile, or a line of the versions file, as each writes it.
arg() {
    local value
    value="$(sed -n "s/^ARG $1=//p" "$dockerfile" | tr -d '"\r' | sed 's/[[:space:]]*$//')"
    [[ -n "$value" && "$value" != *$'\n'* ]] || fail "$dockerfile names no single ARG $1"
    echo "$value"
}
version() {
    local value
    value="$(sed -n "s/^$1=//p" "$versions" | tr -d '"\r' | sed 's/[[:space:]]*$//')"
    [[ -n "$value" && "$value" != *$'\n'* ]] || fail "$versions names no single $1"
    echo "$value"
}
exact() {
    [[ "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$1 is ${2}, not an exact version"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A download into the work folder, kept only if it is of the sum written down.
fetch() {
    local url="$1" out="$work/$2" sha256="$3"
    [[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || fail "the sha256 of $2 is not one: ${sha256}"
    curl -fsSL --proto "=https" --proto-redir "=https" --retry 3 --retry-all-errors -o "$out" "$url" || fail "$url cannot be downloaded"
    echo "${sha256}  ${out}" | sha256sum --check --strict --status - || fail "$2 is not of the sha256 written down, ${sha256}: nothing of it is unpacked"
    echo "$out"
}

paths=("$dir/bin")

for tool in "$@"; do
    case "$tool" in
        tofu)
            v="$(arg OPENTOFU_VERSION)"; exact OpenTofu "$v"
            sum="$(arg "OPENTOFU_SHA256_${upper}")"
            file="$(fetch "https://github.com/opentofu/opentofu/releases/download/v${v}/tofu_${v}_linux_${arch}.tar.gz" "tofu.tar.gz" "$sum")"
            tar -C "$work" -xzf "$file" tofu
            install -m 0755 "$work/tofu" "$dir/bin/tofu"
            echo "install: OpenTofu ${v}" >&2
            ;;
        just)
            v="$(arg JUST_VERSION)"; exact just "$v"
            sum="$(arg "JUST_SHA256_${upper}")"
            file="$(fetch "https://github.com/casey/just/releases/download/${v}/just-${v}-${gnu}-unknown-linux-musl.tar.gz" "just.tar.gz" "$sum")"
            tar -C "$work" -xzf "$file" just
            install -m 0755 "$work/just" "$dir/bin/just"
            echo "install: just ${v}" >&2
            ;;
        node)
            v="$(arg NODE_VERSION)"; exact Node "$v"
            sum="$(arg "NODE_SHA256_${upper}")"
            file="$(fetch "https://nodejs.org/dist/v${v}/node-v${v}-linux-${node_arch}.tar.gz" "node.tar.gz" "$sum")"
            mkdir -p "$dir/node"
            tar -C "$dir/node" --strip-components=1 -xzf "$file"
            paths+=("$dir/node/bin")
            echo "install: Node ${v}" >&2
            ;;
        gcloud)
            v="$(version GCLOUD_VERSION)"; exact "the Google Cloud CLI" "$v"
            sum="$(version "GCLOUD_SHA256_${upper}")"
            file="$(fetch "https://storage.googleapis.com/cloud-sdk-release/google-cloud-cli-${v}-linux-${gcloud_arch}.tar.gz" "gcloud.tar.gz" "$sum")"
            tar -C "$dir" -xzf "$file" google-cloud-sdk
            [[ "$(cat "$dir/google-cloud-sdk/VERSION")" == "$v" ]] || fail "the Google Cloud CLI's archive holds another version than ${v}"
            paths+=("$dir/google-cloud-sdk/bin")
            echo "install: the Google Cloud CLI ${v}" >&2
            ;;
        jq)
            v="$(version JQ_VERSION)"; exact jq "$v"
            sum="$(version "JQ_SHA256_${upper}")"
            file="$(fetch "https://github.com/jqlang/jq/releases/download/jq-${v}/jq-linux-${arch}" "jq" "$sum")"
            install -m 0755 "$file" "$dir/bin/jq"
            echo "install: jq ${v}" >&2
            ;;
        buildx)
            v="$(version BUILDX_VERSION)"; exact buildx "$v"
            sum="$(version "BUILDX_SHA256_${upper}")"
            file="$(fetch "https://github.com/docker/buildx/releases/download/v${v}/buildx-v${v}.linux-${arch}" "buildx" "$sum")"
            plugins="${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins"
            mkdir -p "$plugins"
            install -m 0755 "$file" "$plugins/docker-buildx"
            echo "install: buildx ${v}" >&2
            ;;
        docker)
            want="$(version DOCKER_ENGINE_VERSION)"; exact "the Docker engine" "$want"
            got="$(docker version --format '{{.Server.Version}}')" || fail "the Docker engine does not answer"
            [[ "$got" == "$want" ]] || fail "the runner's Docker engine is ${got}, and tools/ci/versions.env names ${want}: raise it there on purpose, or run where the engine is ${want}"
            echo "install: the Docker engine ${got}, the runner's" >&2
            ;;
        *) fail "no tool ${tool}: tofu, just, node, gcloud, jq, buildx or docker" ;;
    esac
done

for path in "${paths[@]}"; do
    echo "$path"
    if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$path" >> "$GITHUB_PATH"; fi
done
