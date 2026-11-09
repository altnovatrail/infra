# infra

[![CI](https://github.com/altnovatrail/infra/actions/workflows/ci.yml/badge.svg)](https://github.com/altnovatrail/infra/actions/workflows/ci.yml)
[![CodeQL](https://github.com/altnovatrail/infra/actions/workflows/codeql.yml/badge.svg)](https://github.com/altnovatrail/infra/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/altnovatrail/infra/badge)](https://scorecard.dev/viewer/?uri=github.com/altnovatrail/infra)
[![License](https://img.shields.io/github/license/altnovatrail/infra)](LICENSE)

[![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)

The shared infrastructure of NovaTrail: the cloud projects, the identities that let CI deploy, the image registry, the secrets, the budgets, the domains, the logs and the hosting of the app's build, and the way to run the whole platform yourself, on your own servers or on one machine. It deploys the platform's services and the app's build by one list of exact versions and digests, building each service's image from the signed files of its release, and self-hosting takes the same list. It holds no learner's data and no code of the platform's services.

A component of [NovaTrail](https://github.com/altnovatrail/spec/tree/v0.12.0), a universal open platform for adaptive learning, interactive lessons and AI tutoring. It belongs to stage 2, First slice with learners, with tutor, canvas, api, app and skill-map.

## Status

Detailed, and the first code is done. The first epic of [RUN.md](RUN.md) decided what the component's card left open (finished 2026-11-08), and the second, the first code, built the configuration and the deployment and brought up the platform's project, `novatrail` (finished 2026-11-09); the first deployment waits for releases of `api` and `app` (the next epic, E4). The infrastructure is described with OpenTofu, the open fork of Terraform (spec's question Т-29, closed by the 2026-11-08 amendment to R11 spec): it is in the devcontainer with ShellCheck, with its own CI check (R09), and `tofu/` holds the root module and `bootstrap.sh`, the one-time step that makes the project, its state bucket and the federated identity CI applies the configuration as (R10–R13); `deploy/schema/` and `tools/deploy-check/` hold the schema of the deployment's list and its checks (R14), `tools/deploy/` and `.github/workflows/deploy.yml` deploy by the list (R15, R17, R18), and the list itself comes with the first deployment. The region of the platform's data, spec's question П-11, is decided: the US, with Cloud Run and infra's regional resources in `us-east4` and `api`'s Neon database in `aws-us-east-1` (R109 spec).

## Documents

The documents are in Russian.

- [docs/architecture.md](docs/architecture.md) — the component: what it does and does not do, its data and links, and what is still to decide.
- [docs/decisions.md](docs/decisions.md) — the decision log: what was decided, why, and what was rejected.
- [RUN.md](RUN.md) — the work plan, in epics.

The working rules, for people and coding agents alike, are in [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md). The platform's shared vocabulary, formats, contracts and decisions are in [spec](https://github.com/altnovatrail/spec/tree/v0.12.0), checked out here as a git submodule at `v0.9.16`: clone this repository with `git clone --recurse-submodules`.

## License

[Apache-2.0](LICENSE).
