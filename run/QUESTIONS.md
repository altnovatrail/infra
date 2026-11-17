# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В55.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В49 | «В реестр spec». From T59's merge the bucket of `us-east4` keeps the Data Access entries of Secret Manager's version reads, `AccessSecretVersion` and `GetSecretVersion`, 30 days, with `principalEmail` and `callerIp` of the reader: `api-run`, the deployment's and CI's accounts, the eval jobs of `modules` and `tutor` from GitHub's runners through `github-eval`, the operator (the 2026-11-17 amendment to R07). privacy 4 spec, row «Logs», says the platform's logs in `us-east4` are "without direct identifiers and IP addresses", and that the audit holding the email and IP address of the operator and CI is Admin Activity in `_Required`. Nothing of a learner or an account owner is in these entries. How should spec record it? | T59 | (a) a sentence in the row «Logs» of privacy 4 spec, as for Admin Activity: the audit of the reads of the secrets in `us-east4`, 30 days, holds the email and IP address of the reader — the platform's service accounts, CI, the eval jobs and the operator —, and no entry of an account owner or a learner (R07 infra); (b) nothing: these are no learners' data, and "without direct identifiers" reads as of learners | (a): the row already names the audit's emails and addresses of the operator and CI, and without the sentence it misstates what the region's bucket keeps |
