# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions that tasks leave (R153 spec, R160 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row is a question a task leaves open (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В59.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В58 | Решено исполнителем по рекомендации, до проверки автора. The entries of the log that record a move to a tag of `spec` — R01–R03, and those of the later sections "The `spec` tag …" that T99–T102 take — are chronicles of what each tag brought, nearly all of it citations of `spec`'s decisions, sections and tasks. By the strict rule of citations, how is such an entry rewritten? | T98 | (a) the decision it still holds, in force and in words — R01: the documents' check and the template taken whole; R02: a move to the latest release at once; R03: what follows from a decision of `spec`'s register is recorded here once the submodule holds it —, the chronicle of what the tag brought dropped, git and the archives keep it; (b) the chronicle kept, each citation said in words: the entries stay history, against "a text holds the current state", at three times the size; (c) each entry cut to "a move to a tag is no entry of the log": the options they reject, still in force, are lost | (a), taken in T98: what each tag brought already lives in the entries and documents it changed, and a move to a tag is no entry of the log; the author's check may bring back a part of a chronicle that still matters |
