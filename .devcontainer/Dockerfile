# Development container for NovaTrail's infra.
# Exact versions only: the base image is pinned by digest, every tool below by an ARG default.
# Anything a builder understands: no heredocs, no RUN --mount, no TARGETARCH — architecture is
# detected at RUN time via dpkg instead. A host that has Docker can build this, and that is the
# whole requirement.
#
# Two stages. `toolchain` holds what it takes to check the repository — its documents, and its
# code where it has any — and is the stage the automated checks run inside. `devcontainer` adds
# what a person needs on top of that and is the default stage, so building this file with no
# target gives the full environment.

# -- toolchain: checks the repository ----------------------------------------

FROM mcr.microsoft.com/devcontainers/base:3.0.12-noble@sha256:ec556aed93f62aa6d13fe72c5db09da4e29a7c9b87c568dbca0ee5717466926a AS toolchain

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Node.js LTS: the checks of spec's justfile — of the documents, of the licenses, of the files of
# a release and, in spec, of the schemas — are npm packages, and a repository's TypeScript runs
# on it too.
ARG NODE_VERSION=24.21.0
ARG JUST_VERSION=1.58.0
# Go: a repository's Go code is built, vetted and tested with it, and CodeQL reads that code from
# a build with it, in /usr/local/go, where the shared CodeQL workflow of .github looks for Go in
# this stage. In spec that code is its Go module, which code of the platform takes from a
# release, and the Go tools in tools/, and spec's checks build the module's zip as the Go module
# proxy will (R64 spec). Go comes with this file into the copy of every NovaTrail repository, whatever
# its kind, and stays unused in one without Go code (R64 spec).
ARG GO_VERSION=1.27.3
# buf: the API contracts are protobuf files that buf formats, lints, compares with the previous
# release and generates code from, and spec's checks run it on its contracts/ (R83 spec). It comes
# with this file into the copy of every NovaTrail repository, as Go does, and stays unused in one
# without contracts: the other repositories take the generated code from a release of spec.
ARG BUF_VERSION=1.75.0
# OpenTofu: infra describes the platform's infrastructure with it, as code on the model of
# canvas-api's infra/, and its checks — tofu fmt, validate and test — run in this stage. It is the
# one tool this repository's container has beyond spec's, and spec's template does not carry it:
# a move to a new tag of spec keeps it (R09). It never ships, and its license, MPL 2.0, is the
# named exception R09 makes (R12 spec).
ARG OPENTOFU_VERSION=1.13.9
# ShellCheck: the analyser of tofu/bootstrap.sh, the script that makes the project, its federated
# pool and the identity the configuration is applied as, once, with the operator's own rights
# (R13). The second tool beyond spec's container, kept the same way; it never ships, and its
# license, GPL-3.0, is the named exception of the 2026-11-09 amendment to R09 (R12 spec).
ARG SHELLCHECK_VERSION=0.11.0
# actionlint: the check of the workflows, the deployment's among them, which runs only after a merge
# and so cannot show its mistakes in the pull request (R18). The third tool beyond spec's container,
# kept the same way; it never ships, and its license, MIT, is compatible with Apache-2.0 (the second
# 2026-11-09 amendment to R09). It calls the ShellCheck above on the workflows' scripts.
ARG ACTIONLINT_VERSION=1.7.12
# The sha256 of every archive, per architecture, as its publisher lists it: SHASUMS256.txt of
# the Node release, SHA256SUMS of the just release, the sha256 go.dev/dl lists for Go,
# sha256.txt of the buf release, whose binary comes as it is, with no archive, and
# tofu_<version>_SHA256SUMS of the OpenTofu release, whose own signature is checked by hand with
# gpg each time the version is raised (R09), actionlint_<version>_checksums.txt of the actionlint
# release, and, for ShellCheck, which publishes no list of sums,
# the digest GitHub gives each asset of the release, checked against the archive itself. A sum written here keeps a download from being
# swapped once it has been read (R34 spec), and is raised together with its version.
ARG NODE_SHA256_AMD64=6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff
ARG NODE_SHA256_ARM64=724282c3b43aec998aa9527380465b45d229e021b58035f5f4f63095eabfe5d5
ARG JUST_SHA256_AMD64=4a5cc2f53e6f0f8c59092a6cc38291eb729d46a7dd95d3ae582008881b84931d
ARG JUST_SHA256_ARM64=748237128c4c40cbdabc65e841d05ceba13cc23a91eaba395495894c1d9764df
ARG GO_SHA256_AMD64=65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40
ARG GO_SHA256_ARM64=a06e99309dbcbdca1a8ccd2282c3ee146e55930886e26b4f1193269587165f49
ARG BUF_SHA256_AMD64=fad1e38d6909bbb583a4da81d8c02a01046e2cd663bde7e337dd24277393764b
ARG BUF_SHA256_ARM64=00eb190aa82df17f393e05b04889cc60a0b13b3259d336e21a87d5f23ab4fd26
ARG OPENTOFU_SHA256_AMD64=b34b327cc1ef07178207b6f2cd1f5276537d3e5b7be316500f6dac50d4c0a857
ARG OPENTOFU_SHA256_ARM64=5dc196dde75b667e4806d358310ec96742774cd0993c54c1237efee5644b69b8
ARG SHELLCHECK_SHA256_AMD64=b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6
ARG SHELLCHECK_SHA256_ARM64=68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc
ARG ACTIONLINT_SHA256_AMD64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG ACTIONLINT_SHA256_ARM64=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6

# Every archive comes through one helper, so that every download is retried the same way and
# checked against its sum before anything unpacks it. --retry-all-errors is the point of it: a
# transfer that dies partway is not something a plain --retry repeats, and that is exactly the
# failure a small tunnel MTU produces. An archive that still comes short fails its sum.
RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) node_arch=x64; gnu_arch=x86_64; \
            node_sha256="$NODE_SHA256_AMD64"; just_sha256="$JUST_SHA256_AMD64"; go_sha256="$GO_SHA256_AMD64"; \
            buf_sha256="$BUF_SHA256_AMD64"; tofu_sha256="$OPENTOFU_SHA256_AMD64"; \
            shellcheck_sha256="$SHELLCHECK_SHA256_AMD64"; actionlint_sha256="$ACTIONLINT_SHA256_AMD64" ;; \
        arm64) node_arch=arm64; gnu_arch=aarch64; \
            node_sha256="$NODE_SHA256_ARM64"; just_sha256="$JUST_SHA256_ARM64"; go_sha256="$GO_SHA256_ARM64"; \
            buf_sha256="$BUF_SHA256_ARM64"; tofu_sha256="$OPENTOFU_SHA256_ARM64"; \
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

# GOTOOLCHAIN=local: the Go above runs every go command, and none downloads another Go because a
# go.mod asks for a newer one: a go.mod that does fails, which is the signal to raise GO_VERSION.
ENV PATH="/usr/local/node/bin:/usr/local/go/bin:/home/vscode/.local/bin:${PATH}" \
    GOTOOLCHAIN=local

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
# The helper below is the toolchain stage's, written again rather than left in that image as a
# script: the toolchain image is the one the checks run in, and nothing there needs it.
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

# Claude Code comes from the registry at an exact version, rather than from an installer
# script run off the network: what arrives is the package that version names, and npm checks
# the archive against the hash the registry publishes for it. No package's install script runs.
# The one step the package needs — install.cjs, which puts the native binary from its platform
# package in place of the stub it ships with — is run by name, after the install. Without it
# `claude` is that stub, a shell script that says the native binary is not installed and exits
# 1; the package's Node wrapper is a fallback a person starts by hand. install.cjs exits 0 even
# when the platform's binary is missing, and leaves the stub in place: claude --version stops
# the build on it. npm's download cache under root's home is cleared in the same layer, since
# the container runs as vscode.
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
