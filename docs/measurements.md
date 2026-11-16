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
