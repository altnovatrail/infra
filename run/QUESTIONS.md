# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В58.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В56 | «В реестр spec». Row 6.26 of COORDINATION.md `spec` is done: E6 `infra` — T56–T60, T62, T63 and its summary T61, 2026-11-17. `infra` is on `spec` v0.18.6 (T56, T66, T68; R30, R34, R35); the plan is in `run/` and in English (R31); CI is on `.github` v0.1.31 (T63, T65, T66); the texts follow `spec`'s answers to В24–В35 (T57); the rule `age` 364 on `eval-set/samples/` stands on the bucket (T58; row Д239 `spec`); the reads of the secrets are audited (T59; В49, recorded by T188 `spec`); Google's security mail reaches the operator, and a removed `bucketUploader` stops a signed page at once (T60). Outside the epic, during it: platform AI on `novatrail` — rows 6.21 and 6.24 (T69, T70), `api` v0.1.60 and `app` v0.1.23 (T72, T73, T75, T76), english-essays waits on row 6.39 (T77; Д31). Left: the operator's own project for the buckets and part 2 of BREACH.md by R152 `spec` — the proposed E7 (Д23, Д25; rows Д240 and Д249 `spec`). What should spec record? | T61 | (a) close row 6.26, E6 done, and name E7 as a row of item 6 once the author picks it; (b) keep 6.26 open until E7 is picked | (a): every task of E6 is done, and E7 is a new epic with a row of its own |
| В57 | «В реестр spec». Row 6.36 of COORDINATION.md `spec` is done: `novatrail/english-essays` 0.2.1 is in `api_catalog_modules` of `novatrail` with `api` v0.1.62, deployed 2026-11-17 (T78, pull request 114; the fourth 2026-11-17 amendment to R25); `SELF-HOSTING.md`, «Your list», cites the fifth 2026-11-17 amendment to R07 spec and the term 2027-01-17 (T77, T79); В49 left table 3 once T188 `spec` recorded it, and В51 and В52 by T77. `infra` is on `spec` v0.18.17 (T79; R36), and its check refuses a list at the rung `author` with facts for a category under 18 (the fifth 2026-11-17 amendment to R149 spec; the third 2026-11-17 amendment to R05). Row 6.39 is T78 too. What should spec record? | T79 | (a) close rows 6.36 and 6.39 once the bodies of T78 and T79 are in `docs/plan/E6.md` on `main`, each with its «Сделано»; (b) close 6.36 alone, 6.39 with the check of the next week | (a): both rows are the one deployment of T78, and the move is T79 |
