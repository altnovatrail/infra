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

A component of [NovaTrail](https://github.com/altnovatrail/spec/tree/v0.16.3), a universal open platform for adaptive learning, interactive lessons and AI tutoring. It belongs to stage 2, First slice with learners, with tutor, canvas, api, app and skill-map.

## Status

Detailed, built and deployed. The first epic of [RUN.md](RUN.md) decided what the component's card left open (finished 2026-11-08), and the second, the first code, built the configuration and the deployment and brought up the platform's project, `novatrail` (finished 2026-11-09). The third, self-hosting and running the whole platform locally, is done too (finished 2026-11-10): [SELF-HOSTING.md](SELF-HOSTING.md) is the operator's guide, held by tests on a copy's values. The fourth, the first deployment, rolled out `api` v0.1.22 and `app` v0.1.0 by the list to `https://novatrail.web.app` (finished 2026-11-12). The current epic, E5, is the operator's bucket and the written procedure for a breach. The infrastructure is described with OpenTofu, the open fork of Terraform (spec's question Т-29, closed by the 2026-11-08 amendment to R11 spec): it is in the devcontainer with ShellCheck and actionlint, with its own CI check (R09), and `tofu/` holds the root module and `bootstrap.sh`, the one-time step that makes the project, its state bucket and the federated identity CI applies the configuration as (R10–R13); `deploy/schema/` and `tools/deploy-check/` hold the schema of the deployment's list and its checks (R14), `tools/deploy/` and `.github/workflows/deploy.yml` deploy by the list (R15, R17, R18), and `deploy/production.json` is the platform's list (R25). The region of the platform's data, spec's question П-11, is decided: the US, with Cloud Run and infra's regional resources in `us-east4` and `api`'s Neon database in `aws-us-east-1` (R109 spec).

## Documents

The documents are in English; the work plan, its technical debt and the archives of its epics are in Russian.

- [docs/architecture.md](docs/architecture.md) — the component: what it does and does not do, its data and links, and what is still to decide.
- [docs/decisions.md](docs/decisions.md) — the decision log: what was decided, why, and what was rejected.
- [docs/sources.md](docs/sources.md) — the external facts the documents rest on, each with its source, its date and its quote.
- [RUN.md](RUN.md) — the work plan, in epics.
- [DEBT.md](DEBT.md) — the technical debt, in Russian: table 4 of the work plan.
- [SELF-HOSTING.md](SELF-HOSTING.md) — how to bring up your own copy of the platform, from an empty Google Cloud account to a copy ready to deploy, and how to run the whole platform from source on one machine (section 12).
- [BREACH.md](BREACH.md) — what the operator does in a breach of learners' data: what counts as one, how to cut the access, where to look, whom to tell and by when.

The working rules, for people and coding agents alike, are in [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md). The platform's shared vocabulary, formats, contracts and decisions are in [spec](https://github.com/altnovatrail/spec/tree/v0.16.3), checked out here as a git submodule at `v0.16.3`: clone this repository with `git clone --recurse-submodules`.

## License

[Apache-2.0](LICENSE).
