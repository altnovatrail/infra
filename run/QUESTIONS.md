# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В47.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В46 | T58's rule on `eval-set/samples/` — `Delete` at `age` 364, the sixth rule of the operator's bucket — is in `tofu/bootstrap.sh`, but not on the project: the script runs with the operator's rights, and the executor has neither `gcloud` nor them. A change to the script runs again by the operator before the merge that needs it (R13), and an eval-set link waits on the rule (row Д239 spec). When does the author run it? | T58 | (a) now, before the merge: `BOOTSTRAP_MEASURE_ORGANIZER`, `BOOTSTRAP_EVAL_SET_ORGANIZER`, `BOOTSTRAP_OPERATOR` and `TF_VAR_billing_account` set, `just bootstrap` on the branch `t58-samples-lifecycle`, then `gcloud storage buckets describe gs://novatrail-operator --format='json(lifecycle_config)'` — six rules; its output goes to T58's «Сделано»; (b) at T60's visit to the project, after the merge — one visit for both, but the merge goes before the run R13 asks for, and T58 stays `[ ]` until then | (a): R13 and T58 itself ask for the run before the merge, it changes only the bucket's rules, and it costs nothing |
