# The documents of infra

What the [README](../README.md) of the repository leaves out, which says only what the component is and where it stands in NovaTrail (the second 2026-11-17 amendment to R21 spec). How to build and run the component, and anything else of the kind, is added here as it comes, or in a document of its own that this list names.

- [architecture.md](architecture.md) — the component: what it does and does not do, its data and links, and what is still to decide.
- [decisions.md](decisions.md) — the decision log: what was decided, why, and what was rejected.
- [sources.md](sources.md) — the records of external facts the documents rest on, each with its source, its date and its quote.
- [measurements.md](measurements.md) — what was measured, how, on what, and the numbers.
- [RUN.md](../RUN.md) — the work plan, in epics; the done epics are archived in [plan/](plan/).
- `run/` — the plan's other tables: [the epics for later](../run/EPICS.md), [the open questions](../run/QUESTIONS.md), [the technical debt](../run/DEBT.md) and [the tasks outside an epic](../run/TASKS.md).
- [SELF-HOSTING.md](../SELF-HOSTING.md) — how to bring up your own copy of the platform, from an empty Google Cloud account to a copy ready to deploy, how to run the whole platform from source on one machine (section 12), and how an organizer makes an upload link to the operator's bucket (section 13).
- [BREACH.md](../BREACH.md) — what the operator does in a breach of learners' data: what counts as one, how to cut the access, where to look, whom to tell and by when.

The working rules, for people and coding agents alike, are in [CLAUDE.md](../CLAUDE.md) and [AGENTS.md](../AGENTS.md). The platform's shared vocabulary, formats, contracts and decisions are in [spec](https://github.com/altnovatrail/spec), checked out here as a git submodule: clone this repository with `git clone --recurse-submodules`.
