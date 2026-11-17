# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В48.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В47 | T59 has to see `AccessSecretVersion` entries on the project before (a) or (b) of [architecture 2.8](../docs/architecture.md#28-auditing-the-reads-of-the-secrets) is decided — what an entry holds besides the caller and `callerIp`, how many a day `api-run` and the jobs write, the cost —, and the executor has neither `gcloud` nor the project's rights. Today no such entry exists: `DATA_READ` is off, and the exclusion `data-access-audit` of `_Default` would drop it anyway (R07). Turning it on is the author's (rule 4: logs beyond the first 50 GiB a project a month are paid, sources 7.1). How is it turned on for the check? | T59 | (a) by the module at once, as option (a) of 2.8: `google_project_iam_audit_config` with `DATA_READ` for `secretmanager.googleapis.com` in `tofu/logging.tf`, the exclusion `data-access-audit` let through for that service alone, tests; `bootstrap.sh` names the new type under `roles/resourcemanager.projectIamAdmin` (R13) — whether its condition `modifiedGrantsByRole` lets `infra-config` write `auditConfigs` is not verified, so the author reruns `just bootstrap` from the branch before the merge; a day after the merge's apply the author runs one `gcloud logging read` the task gives and passes its output; T59 then records (a), or reverts to (b) in a pull request of its own; (b) by hand, temporarily: in Cloud Shell the author adds `auditConfigs` by `gcloud projects get-iam-policy`/`set-iam-policy` and disables the exclusion `data-access-audit` of `_Default` — every Data Access entry then passes, not only Secret Manager's —, reads a day later, passes the output and undoes both; an `apply` of a merge in between restores the exclusion; T59 then writes (a) or (b) in code; (c) no check: 2.8 decided (b) now, the reason being that the entries were not seen | (a): the project and the module never differ, the check reads exactly the configuration that stays, only Secret Manager's entries pass, and a revert is one pull request; (b) changes the project behind the module and lets through more than it checks |
