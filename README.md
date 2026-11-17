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

A component of [NovaTrail](https://github.com/altnovatrail/spec), a universal open platform for adaptive learning, interactive lessons and AI tutoring. It belongs to stage 2, First slice with learners, with tutor, canvas, api, app and skill-map.

## Documents

- [docs/architecture.md](docs/architecture.md) — the component: what it does and does not do, its data and links, and what is still to decide.
- [docs/decisions.md](docs/decisions.md) — the decision log: what was decided, why, and what was rejected.
- [docs/sources.md](docs/sources.md) — the external facts the documents rest on, each with its source, its date and its quote.
- [RUN.md](RUN.md) — the work plan, in epics.
- `run/` — the plan's other tables: [the epics for later](run/EPICS.md), [the open questions](run/QUESTIONS.md), [the technical debt](run/DEBT.md) and [the tasks outside an epic](run/TASKS.md).
- [SELF-HOSTING.md](SELF-HOSTING.md) — how to bring up your own copy of the platform, from an empty Google Cloud account to a copy ready to deploy, how to run the whole platform from source on one machine (section 12), and how an organizer makes an upload link to the operator's bucket (section 13).
- [BREACH.md](BREACH.md) — what the operator does in a breach of learners' data: what counts as one, how to cut the access, where to look, whom to tell and by when.

The working rules, for people and coding agents alike, are in [CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md). The platform's shared vocabulary, formats, contracts and decisions are in [spec](https://github.com/altnovatrail/spec), checked out here as a git submodule: clone this repository with `git clone --recurse-submodules`.
