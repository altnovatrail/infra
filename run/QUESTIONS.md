# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В45.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В44 | «В реестр spec», for `tutor`: on `novatrail`, the first «Проверить» with platform AI on a task of `novatrail/check-board` («Реши уравнение 3x + 1 = 7»), a legible wrong solution was answered «Пока не верно: 1 пункт из 1» and «Пункт 1 • Не получается прочитать — Читается двояко», not a frame round the error: the pair of readers, `claude-opus-5-5` at high effort and `claude-haiku-5-5` at medium, disagreed (R68 spec). The one check cost 8676 millionths of a dollar — Opus 8276, Haiku 400 — by the lines `ai_usage` of `api` v0.1.55 (2026-11-17; T69). The reading on the site is worse than `tutor`'s eval shows, and dearer, by the author's word | T69 | (a) a task of `tutor` that analyses the disagreement — the crops and prompts of the two readers, their eval on the board's tasks, the cost of the pair — before T158 spec: the orchestrator sets it, by the author's word of 2026-11-17; (b) nothing now: the board's tasks stay unreadable for the author until the eval of П-16 | (a): the author's word, and the module the platform is opened for cannot be begun without it |
