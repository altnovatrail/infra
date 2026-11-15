# infra — measurements

> The results of the repository's measurements: what was measured, how, on what, and the numbers (RULES.md, How we work; R143 spec). The documents that describe how things are built cite them as a section, `measurements 1`; the external facts they rest on are records of [sources.md](sources.md). A measurement taken again is a new row or item with its date, and an earlier one is not edited.

## 1. Tokens of the epics' sessions

At the archive of an epic, `just -f spec/justfile tokens-report --since … --until … --row` measures the sessions of Claude Code in the epic's window, on the author's machine, by their transcripts in the folder `-workspaces-infra` (RUN.md, «Как устроен план: эпики»; measurements 1.9 spec). A window runs from the commit that archived the epic before to the start of the session that archives this one. A session that crosses a boundary is counted by its calls inside the window.

| Epic | Window, UTC | Sessions | Calls, main / subagents | Context of a call, k, main / subagents | Compactions | Cost at API prices |
|---|---|---|---|---|---|---|
| before R143 spec — the row `-workspaces-infra` of measurements 1.9 spec, E1–E4 | 2026-10-13T00:00 … 2026-11-12T14:27 | 6 | 2,175 / 1,714 | 354.7 / 80.0 | 6 | $321.70 |
| E5, with T52, T53 and T55 outside it | 2026-11-12T20:27 … 2026-11-15T02:21 | 17 | 1,613 / 709 | 177.8 / 90.6 | 1 | $150.22 |

- Measured 2026-11-15, when E5 was archived. The window of E5 starts after f79f0f2, the commit that closed E4, so the session of T38 and of E5's planning counts by its calls after it.
- After R143 spec — one task, one session, since T52 — the context of a main call fell from 354.7 to 177.8 thousand, −50%. The windows differ in work: the detail, the first code and the first deployment against the bucket and the breach procedure. This repository's reference for the threshold of R145 spec is the measurement after, by T124 spec.
