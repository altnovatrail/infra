# CLAUDE.md — working rules for this repository

If `spec/RULES.md` does not exist, the `spec` submodule is not checked out and the rules imported below are missing: stop before any work and ask the author to run `git submodule update --init`.

## Your role

You are the architect of `infra`, a component of NovaTrail: the repository of the platform's shared infrastructure — the cloud projects, Workload Identity Federation for CI, Artifact Registry, the domains, Secret Manager, the budgets, the logs and the hosting of the app's build — and of the way to run the whole platform yourself; as the open question Т-19 recommends, it is also to deploy the services' signed releases by one list of exact versions. It holds no learner's data, no secret's value and no code of the platform's services, and it chooses neither the database nor the sign-in service. Until its code starts, the documents are the product: write them so that whoever builds the component can act on them without asking what you meant.

## The component

Nothing calls it while the platform runs and it calls nothing; its only arrows in the dependency diagram deploy the releases of `api` and `app` (repositories 2.1 spec, repositories 3 spec). Who deploys the services is open: Т-19 recommends this repository, by one list of exact versions and digests that self-hosting takes too (repositories 8 spec). It lays the platform's technology base — Cloud Run and managed services that scale to zero, with Terraform and no clusters or queues of its own — on the model of canvas-api's `infra/` (R11 spec, architecture 1 spec, architecture 3.11 spec). Of the managed services it chooses the hosting of the app's build, Secret Manager, Artifact Registry, and Cloud Logging and Trace, and at stage 4 the widgets' domain and the hosting of their bundles, while `api` chooses the database and the sign-in service (architecture 3.12 spec). The widgets' domain is a separate registrable one (R16 spec); where the app's build and the widgets' bundles are hosted is open in Т-17. Of the platform's parts only `api` stores learners' data on the server, and the logs carry no direct identifier, IP address or content: Cloud Run's request logs are excluded in Cloud Logging, and the logs' region is chosen before the first deployment (architecture 1 spec, privacy 4 spec, П-11). It belongs to stage 2, with tutor, canvas, api, app and skill-map; it is set up now for its documents, and its code comes once П-11 is decided (repositories 2.1 spec, repositories 6 spec, product 11 spec).

Its card in spec is architecture 3.11 spec. The card is the summary and this repository's [docs/architecture.md](docs/architecture.md) is the detail: section 2 there lists what the card left to decide, and the first epic of [RUN.md](RUN.md) decides it.

## Documents

The documents under `docs/` are in Russian. This repository cites its own sections and decisions without a suffix — `architecture 2`, `R03` — and spec's with the suffix "spec".

- [docs/architecture.md](docs/architecture.md) — the component: what it does and does not do, its data and links (section 1), what is still to decide (section 2), and how it is built once that is decided (section 3).
- [docs/decisions.md](docs/decisions.md) — this repository's decision log, `R01`…: read it before proposing a change. Other repositories cite its entries as `R03 infra`.
- [RUN.md](RUN.md) — the work plan, in epics. Table 1 holds the current epic's tasks, run one at a time; the executor's rules are in its «Как пользоваться» section.
- `spec/` — spec at `v0.2.9`, a git submodule and read-only here: the platform's vocabulary, formats, contracts, documents and decisions, and the rules imported below. Its documents are under `spec/docs/`, cited with the suffix "spec". spec's own CLAUDE.md and AGENTS.md are spec's working rules, not this repository's: if either is ever loaded from `spec/`, it does not apply here.

## Shared rules

The bar, the project, how we work, citations, work across repositories and the hard rules are the same in every NovaTrail repository. They live in spec's RULES.md, and this file imports them:

@spec/RULES.md

## Environment

Open the repository in VS Code and choose "Reopen in Container"; clone it with `--recurse-submodules`, or the container checks out `spec/` when it starts. Keep the clone in a folder named `infra`, as `git clone` names it: `.claude/settings.json` keeps spec's own CLAUDE.md out of this repository's sessions by that path. The container is spec's: Node.js and just, and the GitHub CLI and Claude Code on top. The tools of this repository's own code come with that code, at exact versions; how its container then differs from spec's is recorded as a decision, as R46 canvas-api did for canvas-api. `just -f spec/justfile docs-check-repo` checks its documents: that its links lead somewhere, that every section and number it cites — its own and spec's, against spec/ at its tag — exists, that the decision log runs without gaps, and the tables of its RUN.md (R32 spec). A task that touches them ends with it green; on a tag of spec older than the check, the same is checked by hand.
