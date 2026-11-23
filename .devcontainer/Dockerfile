# Development container for NovaTrail's infra.
# Exact versions only: the base image is pinned by digest, every tool below by an ARG default.
# Anything a builder understands: no heredocs, no RUN --mount, no TARGETARCH — architecture is
# detected at RUN time via dpkg instead, so any host that has Docker can build this.
#
# `toolchain-core` holds Node, just, Go and buf: what a release needs — its version and its files —
# and every check that runs no browser, and a release builds it alone (R31 spec). `toolchain` adds what
# the repository's tests need — in a copy, its kind's lines at the end of the stage — and is the
# stage the automated checks run inside. `devcontainer` adds what a person needs, and
# devcontainer.json names it as its target. spec's own file ends with `orchestrator`, the
# devcontainer with the Docker CLI and the Dev Containers CLI, which `just new-repo` leaves out of
# a copy (R156 spec, R158 spec): in a copy `devcontainer` is the last stage, the one a build with no target
# gives, and in spec every build names its stage.

# -- toolchain-core: releases the repository, checks it without a browser -----

FROM mcr.microsoft.com/devcontainers/base:3.0.13-noble@sha256:48be4adec1c1ecbe030064700aef85382f5205786a8f82937fc44a7473717eae AS toolchain-core

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Node.js LTS: the checks of spec's justfile are npm packages, and a repository's TypeScript runs
# on it too.
ARG NODE_VERSION=24.21.0
ARG JUST_VERSION=1.58.0
# Go, in /usr/local/go, where the shared CodeQL workflow of .github looks for it: a repository's
# Go code is built, vetted, tested and read by CodeQL with it. In spec that code is its Go module
# and the Go tools in tools/, and the checks build the module's zip as the Go module proxy will.
# Every copy gets Go whatever its kind, unused where there is no Go code (R64 spec).
ARG GO_VERSION=1.27.4
# buf formats, lints, compares with the previous release and generates code from the protobuf
# API contracts, spec's contracts/ (R83 spec). Every copy gets it as it gets Go, unused where there are
# no contracts: the other repositories take the generated code from a release of spec.
ARG BUF_VERSION=1.75.0
# Each archive's sha256 per architecture, as its publisher lists it: SHASUMS256.txt of the Node
# release, SHA256SUMS of just's, go.dev/dl for Go, sha256.txt of buf's, whose binary comes bare. A
# sum written here keeps a download from being swapped, and is raised with its version (R34 spec).
ARG NODE_SHA256_AMD64=6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff
ARG NODE_SHA256_ARM64=724282c3b43aec998aa9527380465b45d229e021b58035f5f4f63095eabfe5d5
ARG JUST_SHA256_AMD64=4a5cc2f53e6f0f8c59092a6cc38291eb729d46a7dd95d3ae582008881b84931d
ARG JUST_SHA256_ARM64=748237128c4c40cbdabc65e841d05ceba13cc23a91eaba395495894c1d9764df
ARG GO_SHA256_AMD64=7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840
ARG GO_SHA256_ARM64=3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92
ARG BUF_SHA256_AMD64=fad1e38d6909bbb583a4da81d8c02a01046e2cd663bde7e337dd24277393764b
ARG BUF_SHA256_ARM64=00eb190aa82df17f393e05b04889cc60a0b13b3259d336e21a87d5f23ab4fd26

# One helper fetches every archive, so each is retried the same way and checked against its sum
# before anything unpacks it. --retry-all-errors is the point: a plain --retry does not repeat a
# transfer that dies partway, the failure a small tunnel MTU produces. An archive still short fails
# its sum.
RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) node_arch=x64; gnu_arch=x86_64; \
            node_sha256="$NODE_SHA256_AMD64"; just_sha256="$JUST_SHA256_AMD64"; go_sha256="$GO_SHA256_AMD64"; \
            buf_sha256="$BUF_SHA256_AMD64" ;; \
        arm64) node_arch=arm64; gnu_arch=aarch64; \
            node_sha256="$NODE_SHA256_ARM64"; just_sha256="$JUST_SHA256_ARM64"; go_sha256="$GO_SHA256_ARM64"; \
            buf_sha256="$BUF_SHA256_ARM64" ;; \
        *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    workdir="$(mktemp -d)"; \
    fetch() { \
        local url="$1" out="$2" sha256="$3"; \
        curl -fsSL --proto "=https" --proto-redir "=https" --retry 3 --retry-all-errors \
            -o "$out" "$url"; \
        echo "${sha256}  ${out}" | sha256sum --check --strict -; \
    }; \
    \
    echo "node ${NODE_VERSION}"; \
    mkdir -p /usr/local/node; \
    fetch "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" \
        "$workdir/node-${NODE_VERSION}-${node_arch}.tar.gz" "$node_sha256"; \
    tar -C /usr/local/node --strip-components=1 -xzf "$workdir/node-${NODE_VERSION}-${node_arch}.tar.gz"; \
    \
    echo "just ${JUST_VERSION}"; \
    fetch "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${gnu_arch}-unknown-linux-musl.tar.gz" \
        "$workdir/just-${JUST_VERSION}-${gnu_arch}.tar.gz" "$just_sha256"; \
    tar -C "$workdir" -xzf "$workdir/just-${JUST_VERSION}-${gnu_arch}.tar.gz" just; \
    install -m 0755 "$workdir/just" /usr/local/bin/just; \
    \
    echo "go ${GO_VERSION}"; \
    fetch "https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz" \
        "$workdir/go-${GO_VERSION}-${arch}.tar.gz" "$go_sha256"; \
    tar -C /usr/local -xzf "$workdir/go-${GO_VERSION}-${arch}.tar.gz"; \
    /usr/local/go/bin/go version; \
    \
    echo "buf ${BUF_VERSION}"; \
    fetch "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-Linux-${gnu_arch}" \
        "$workdir/buf-${BUF_VERSION}-${gnu_arch}" "$buf_sha256"; \
    install -m 0755 "$workdir/buf-${BUF_VERSION}-${gnu_arch}" /usr/local/bin/buf; \
    buf --version; \
    \
    rm -rf "$workdir"

# GOTOOLCHAIN=local: the Go above runs every go command, and none downloads another Go because a
# go.mod asks for a newer one: a go.mod that does fails, which is the signal to raise GO_VERSION.
ENV PATH="/usr/local/node/bin:/usr/local/go/bin:/home/vscode/.local/bin:${PATH}" \
    GOTOOLCHAIN=local

# -- toolchain: the core, plus what infra's own checks need ------------------
#
# OpenTofu, ShellCheck and actionlint: infra's own checks need them, and neither a release nor a
# shared check does, so they are here and not in the core. A move to a new tag of spec keeps this
# stage's lines, as a kind's lines are kept at its end (R09).

FROM toolchain-core AS toolchain

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# OpenTofu: the language of the root module in tofu/, whose fmt, validate and test run in this
# stage. It never ships and puts none of its code into what ships, so its license, MPL 2.0, is
# allowed as a named exception.
ARG OPENTOFU_VERSION=1.13.9
# ShellCheck: the analyser of the repository's shell scripts, and of the workflows' scripts through
# actionlint. It never ships and puts none of its code into what ships, so its license, GPL-3.0,
# is allowed as a named exception.
ARG SHELLCHECK_VERSION=0.11.0
# actionlint: the deployment's workflow runs only after a merge, so this check is where its mistakes
# show before one. Its license, MIT, is compatible with Apache-2.0.
ARG ACTIONLINT_VERSION=1.7.12
# The sums, as in the core: tofu_<version>_SHA256SUMS of the OpenTofu release, whose own signature
# is checked by hand with gpg each time the version is raised, actionlint_<version>_checksums.txt of
# the actionlint release, and, for ShellCheck, which publishes no list of sums, the digest GitHub
# gives each asset of the release, checked against the archive itself. The helper below is the
# core's, written again as the devcontainer stage writes it.
ARG OPENTOFU_SHA256_AMD64=b34b327cc1ef07178207b6f2cd1f5276537d3e5b7be316500f6dac50d4c0a857
ARG OPENTOFU_SHA256_ARM64=5dc196dde75b667e4806d358310ec96742774cd0993c54c1237efee5644b69b8
ARG SHELLCHECK_SHA256_AMD64=b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6
ARG SHELLCHECK_SHA256_ARM64=68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc
ARG ACTIONLINT_SHA256_AMD64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG ACTIONLINT_SHA256_ARM64=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6

RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) gnu_arch=x86_64; tofu_sha256="$OPENTOFU_SHA256_AMD64"; \
            shellcheck_sha256="$SHELLCHECK_SHA256_AMD64"; actionlint_sha256="$ACTIONLINT_SHA256_AMD64" ;; \
        arm64) gnu_arch=aarch64; tofu_sha256="$OPENTOFU_SHA256_ARM64"; \
            shellcheck_sha256="$SHELLCHECK_SHA256_ARM64"; actionlint_sha256="$ACTIONLINT_SHA256_ARM64" ;; \
        *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    workdir="$(mktemp -d)"; \
    fetch() { \
        local url="$1" out="$2" sha256="$3"; \
        curl -fsSL --proto "=https" --proto-redir "=https" --retry 3 --retry-all-errors \
            -o "$out" "$url"; \
        echo "${sha256}  ${out}" | sha256sum --check --strict -; \
    }; \
    \
    echo "opentofu ${OPENTOFU_VERSION}"; \
    fetch "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_${arch}.tar.gz" \
        "$workdir/tofu-${OPENTOFU_VERSION}-${arch}.tar.gz" "$tofu_sha256"; \
    tar -C "$workdir" -xzf "$workdir/tofu-${OPENTOFU_VERSION}-${arch}.tar.gz" tofu; \
    install -m 0755 "$workdir/tofu" /usr/local/bin/tofu; \
    tofu version; \
    \
    echo "shellcheck ${SHELLCHECK_VERSION}"; \
    fetch "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.${gnu_arch}.tar.gz" \
        "$workdir/shellcheck-${SHELLCHECK_VERSION}-${gnu_arch}.tar.gz" "$shellcheck_sha256"; \
    tar -C "$workdir" --strip-components=1 -xzf "$workdir/shellcheck-${SHELLCHECK_VERSION}-${gnu_arch}.tar.gz" \
        "shellcheck-v${SHELLCHECK_VERSION}/shellcheck"; \
    install -m 0755 "$workdir/shellcheck" /usr/local/bin/shellcheck; \
    shellcheck --version; \
    \
    echo "actionlint ${ACTIONLINT_VERSION}"; \
    fetch "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${arch}.tar.gz" \
        "$workdir/actionlint-${ACTIONLINT_VERSION}-${arch}.tar.gz" "$actionlint_sha256"; \
    tar -C "$workdir" -xzf "$workdir/actionlint-${ACTIONLINT_VERSION}-${arch}.tar.gz" actionlint; \
    install -m 0755 "$workdir/actionlint" /usr/local/bin/actionlint; \
    actionlint -version; \
    \
    rm -rf "$workdir"

# -- devcontainer: the toolchain, plus what a person works with --------------

FROM toolchain AS devcontainer

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# The GitHub CLI: pull requests, the runs of the checks and their alerts live only on
# github.com and are invisible from inside a container otherwise.
ARG GH_VERSION=2.101.0
# The language server for justfiles: the just extension in devcontainer.json starts it, and
# warns on every justfile it opens when it is missing.
ARG JUST_LSP_VERSION=0.10.0
# Claude Code CLI. The VS Code extension in devcontainer.json must have the same version.
ARG CLAUDE_CODE_VERSION=2.1.280
# The sums, as above: gh_<version>_checksums.txt of the gh release, SHA256SUMS of just-lsp's.
# The helper below repeats toolchain-core's rather than leaving it in that image as a script: the
# checks run in the toolchain images, and nothing there needs it.
ARG GH_SHA256_AMD64=9bca2d1c16825f109907a23307628a2f0698fbf99662b73a5cf0b020293072b8
ARG GH_SHA256_ARM64=b57e8063f18862647c9d22727c32e9da1b963f8bf9db648fe123a6975695640f
ARG JUST_LSP_SHA256_AMD64=3c35e10e76db6cc1931495bb3abdaef02576eaeb406c217420f4fd37e1ebe22c
ARG JUST_LSP_SHA256_ARM64=88d83e1bfb29f5cf41be1d4056d56311bcdcad81aec57b7737cdd98147547478

RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) gnu_arch=x86_64; gh_sha256="$GH_SHA256_AMD64"; just_lsp_sha256="$JUST_LSP_SHA256_AMD64" ;; \
        arm64) gnu_arch=aarch64; gh_sha256="$GH_SHA256_ARM64"; just_lsp_sha256="$JUST_LSP_SHA256_ARM64" ;; \
        *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    workdir="$(mktemp -d)"; \
    fetch() { \
        local url="$1" out="$2" sha256="$3"; \
        curl -fsSL --proto "=https" --proto-redir "=https" --retry 3 --retry-all-errors \
            -o "$out" "$url"; \
        echo "${sha256}  ${out}" | sha256sum --check --strict -; \
    }; \
    \
    echo "gh ${GH_VERSION}"; \
    fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.tar.gz" \
        "$workdir/gh-${GH_VERSION}-${arch}.tar.gz" "$gh_sha256"; \
    tar -C "$workdir" --strip-components=2 \
        -xzf "$workdir/gh-${GH_VERSION}-${arch}.tar.gz" \
        "gh_${GH_VERSION}_linux_${arch}/bin/gh"; \
    install -m 0755 "$workdir/gh" /usr/local/bin/gh; \
    \
    echo "just-lsp ${JUST_LSP_VERSION}"; \
    fetch "https://github.com/terror/just-lsp/releases/download/${JUST_LSP_VERSION}/just-lsp-${JUST_LSP_VERSION}-${gnu_arch}-unknown-linux-musl.tar.gz" \
        "$workdir/just-lsp-${JUST_LSP_VERSION}-${gnu_arch}.tar.gz" "$just_lsp_sha256"; \
    tar -C "$workdir" -xzf "$workdir/just-lsp-${JUST_LSP_VERSION}-${gnu_arch}.tar.gz" ./just-lsp; \
    install -m 0755 "$workdir/just-lsp" /usr/local/bin/just-lsp; \
    \
    rm -rf "$workdir"

# Claude Code comes from the registry at an exact version, not from an installer script off the
# network: npm checks the archive against the hash the registry publishes, and no install script
# runs. The one step the package needs, install.cjs, which puts the native binary of its platform
# package in place of the stub it ships, runs by name afterwards; without it `claude` is a stub
# that says the binary is not installed and exits 1 (the Node wrapper is a fallback started by
# hand). install.cjs exits 0 even when the binary is missing, so claude --version stops the build
# on the stub. npm's cache under root's home goes in the same layer: the container runs as vscode.
RUN echo "claude code ${CLAUDE_CODE_VERSION}" \
    && npm install -g --ignore-scripts "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs" \
    && claude --version \
    && npm cache clean --force

# The dirs the named volumes are mounted over are created here so the volumes inherit vscode
# ownership — a dir Docker makes for a mount belongs to root, and VS Code Server could not write
# to its own home — and the image is left as that user: nothing in it needs root once it is built.
USER vscode
RUN mkdir -p /home/vscode/.claude /home/vscode/.codex /home/vscode/.config/gh \
        /home/vscode/.vscode-server/extensions
