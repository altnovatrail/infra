# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В44.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В41 | `app`'s check of the site on the pair of T69: `infra`'s container has no browsers of Playwright. In `app`'s container, at its tag: `git fetch --tags && git checkout v0.1.14 && just site-check https://novatrail.web.app v0.1.14`. Answer: its last lines — passed, or what it refused | T69 | (a) passed: T69's «Сделано» names it; (b) refused: the refusal goes into «Открыто» and, if it is `app`'s, into a row «В реестр spec» | (a) is what is wanted; the answer decides |
| В42 | The board task on the site with platform AI, by the author (R149 spec): https://novatrail.web.app → sign in → «Задачи на листе», `novatrail/check-board` → a task → first a wrong answer on the canvas → «Проверить»: «not yet» and a frame round the error; then the right one → «Проверить»: the verdict. And whether «Short essays in English» is gone from the catalog (R150 spec). Answer: what each step showed, in words; no screenshot of a work | T69 | (a) all as said: T69 is done; (b) a step differs — which, and its message: it goes into «Открыто», and to `api` or `app` by a row «В реестр spec» | (a) is what is wanted; the answer decides |
| В43 | What platform AI spent (RUN.md rule 4). (1) In Cloud Shell, as an owner of `novatrail`: `gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="api" AND jsonPayload.message="ai_usage"' --project=novatrail --bucket=default-us-east4 --location=us-east4 --view=_AllLogs --freshness=2d --format='csv[no-heading](jsonPayload.provider,jsonPayload.model,jsonPayload.ai_outcome,jsonPayload.cost_micro_usd)'` — one line per call: provider, model, outcome, cost in millionths of a dollar. (2) Anthropic console, the workspace `novatrail`, usage and cost for 2026-11-17. Answer: the number of calls and the sum by each | T69 | (a) the numbers: T69's «Сделано» names the provider, the calls and the sum; (b) the two sums differ much: «Открыто» names both | (a) |
