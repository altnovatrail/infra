# infra — measurements

> The results of the repository's measurements: what was measured, how, on what, and the numbers (RULES.md, How we work; R143 spec). The documents that describe how things are built cite them as a section, `measurements 1`; the external facts they rest on are records of [sources.md](sources.md). A measurement taken again is a new row or item with its date, and an earlier one is not edited.

## 1. Tokens of the epics' sessions

At the archive of an epic, `just -f spec/justfile tokens-report --since … --until … --row` measures the sessions of Claude Code in the epic's window, on the author's machine, by their transcripts in the folder `-workspaces-infra` (RUN.md, Epics; measurements 1.9 spec). A window runs from the commit that archived the epic before to the start of the session that archives this one. A session that crosses a boundary is counted by its calls inside the window.

| Epic | Window, UTC | Sessions | Calls, main / subagents | Context of a call, k, main / subagents | Compactions | Cost at API prices |
|---|---|---|---|---|---|---|
| before R143 spec — the row `-workspaces-infra` of measurements 1.9 spec, E1–E4 | 2026-10-13T00:00 … 2026-11-12T14:27 | 6 | 2,175 / 1,714 | 354.7 / 80.0 | 6 | $321.70 |
| E5, with T52, T53 and T55 outside it | 2026-11-12T20:27 … 2026-11-15T02:21 | 17 | 1,613 / 709 | 177.8 / 90.6 | 1 | $150.22 |

- Measured 2026-11-15, when E5 was archived. The window of E5 starts after f79f0f2, the commit that closed E4, so the session of T38 and of E5's planning counts by its calls after it.
- After R143 spec — one task, one session, since T52 — the context of a main call fell from 354.7 to 177.8 thousand, −50%. The windows differ in work: the detail, the first code and the first deployment against the bucket and the breach procedure. This repository's reference for the threshold of R145 spec is the measurement after, by T124 spec.

## 2. The speed of CI

### 2.1. The jobs `OpenTofu` and `Deploy` before and after T64, 2026-11-16

The times of the jobs and of their steps from `actions/runs/<id>/jobs` of the GitHub API, and of the recipes from the `duration_ms` that `node --test` prints in the jobs' logs, read 2026-11-16. Before — the run of CI on `main` 43805765623, the merge of T63, with the image from the cache; after — the runs 43810340096 and 43813641572 of pull request 85, on runners `ubuntu-24.04`. One run each: the runners' times vary — `tf-check` took 36 s on `main` and 57 s in the second run of the pull request, with no change to `tofu/`'s module.

| | `main`, 43805765623 | pull request 85, 43810340096 | pull request 85, 43813641572 |
|---|---|---|---|
| `OpenTofu`, the job | 187 s | 111 s, three tests failed (below) | 158 s |
| `bootstrap-test` | 117.3 s, 63 tests one after another | 43.1 s, 63 tests four at a time | 65.8 s, 64 tests four at a time |
| `Deploy`, the job | 68 s | 50 s | 59 s |
| `Deploy`, the step of the recipes | 32 s | 25 s | 27 s |
| `deploy-check-release-test` | 7.7 s, in turn | in the background | 9.0 s, in the background |

- **The race.** In 43810340096 three tests of `bootstrap.sh` failed, each a run again that did not find a bucket it had made; four runs of the suite in the devcontainer, on four of its cores by `taskset -c 0-3`, failed one to two tests each. The cause was `grep -q` under `pipefail` in `bootstrap.sh` (the 2026-11-16 amendment to R32); with it fixed, three runs on four cores — 64 of 64 each.
- **Locally.** The devcontainer, 20 cores: `just bootstrap-test` took 130 s with the tests one after another, 95 s of user time, and 45 s four at a time, 121 s of user time; on four of its cores, 130–141 s four at a time. Its times change with what else the machine runs.

### 2.2. The image of the stage `toolchain` before and after T65, 2026-11-16

The times of the runs, the jobs and their steps from `actions/runs/<id>` and `actions/runs/<id>/jobs` of the GitHub API, the steps of the composite action `.github/actions/toolchain` as one step; the rest from the jobs' logs, read 2026-11-16. Before — on `.github` v0.1.24, each job restoring the entry itself: the run of CI on `main` 43818580587, the merge of T57, and of pull request 86, 43817589511. After — on v0.1.30 with the job `Toolchain image` (the second 2026-11-16 amendment to R32): pull request 87, 43855940093, with the entry of `main`, and the trial pull request 88, not for merge, 43855945017, whose action looked for a key no entry held, so that `Toolchain image`, `OpenTofu` and `Deploy` missed while the shared Documents check hit. One run each, on runners `ubuntu-24.04`, while the orchestrator ran other repositories' CI.

| | `main`, 43818580587 | PR 86, 43817589511 | PR 87, 43855940093, a hit | PR 88, 43855945017, a miss |
|---|---|---|---|---|
| the run, from its creation to its end | 129 s | 145 s | 187 s | 356 s |
| `Toolchain image`, the job | — | — | 5 s, the lookup under 1 s | 60 s |
| `OpenTofu` starts, after the run's creation | 18 s | 2 s | 18 s | 186 s |
| `OpenTofu`, the job / the image / the recipes | 110 / 17 / 84 s | 143 / 37 / 100 s | 169 / 32 / 128 s | 169 / 49 / 114 s |
| `Deploy` starts, after the run's creation | 7 s | 3 s | 12 s | 138 s |
| `Deploy`, the job / the image / the recipes | 53 / 17 / 26 s | 72 / 37 / 29 s | 81 / 43 / 32 s | 77 / 35 / 36 s |

- **The miss.** In `Toolchain image` the build took 16 s, `docker save` about 8 s and the upload 19 s; the artifact `toolchain-image` is 535,180,543 bytes at level 1, kept to 2026-11-17. `OpenTofu` and `Deploy` each logged "Cache not found", downloaded it by its ID in 11–12 s with its SHA256 digest checked, and loaded it: neither ran the Dockerfile. Neither pull request saved an entry: `actions/caches?key=toolchain` holds none of the trial's key and none of `refs/pull/87/merge` or `refs/pull/88/merge` — only the entry of `refs/heads/main` and those of pull requests 82 and 83 from before T65, which go after seven days unread.
- **The waits.** In the trial `OpenTofu` waited 123 s and `Deploy` 75 s for a runner after `Toolchain image` ended, when the jobs of other repositories' runs held the organization's runners; on a hit the two started 12–18 s after the run, against 2–3 s in pull request 86 before T65 and 7–18 s on `main`: the wait for `Toolchain image` and a second runner, which a hit pays on every run. The run of pull request 87 took 42 s longer than that of 86, and its recipes in `OpenTofu` 28 s longer, with the same module and tests: the runners' times vary, as in measurements 2.1, and one run each does not tell T65's part from that.

### 2.3. The stages `toolchain-core` and `toolchain`, T66, 2026-11-16

The sizes of the three tools of R09 as the stage `toolchain` installs them, by `ls -l` of `/usr/local/bin` in the devcontainer, 2026-11-16: `tofu` 114,192,544 bytes, `shellcheck` 16,213,136 and `actionlint` 6,074,530, 136,480,210 together. The image of `toolchain` holds them beyond the core, and `toolchain-core`, which the Documents check and `Deploy` load, does not (R34).

The run of CI of pull request 90, 43907985039, a miss of both entries, since the Dockerfile is new; the times from `actions/runs/<id>/jobs` of the GitHub API and the jobs' logs, read 2026-11-16:
- **the run** — 296 s from its creation to its end, all green;
- **`Toolchain image`** — 106 s: the core built, saved and uploaded as `toolchain-core-image`, 489,200,988 bytes at level 1, by 16:30:26, 61 s after the job's first lookup; then `toolchain` as `toolchain-image`, 535,206,283 bytes, by 16:31:04, 37 s more;
- **Documents** — "The checks without a browser run in the stage toolchain-core.", "Cache not found" for `toolchain-core-Linux-X64-<sha256>`, its own build, 48 s;
- **`Deploy`** — 104 s, the core by the artifact's ID after "Cache not found"; **`OpenTofu`** — 148 s, `toolchain` the same way. Neither ran the Dockerfile.
