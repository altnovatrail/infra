# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В41.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В38 | The spend limit of the Anthropic workspace whose key the platform will use on `novatrail` (Д11 `api`; R25, its 2026-11-16 amendment): it comes before the key. In the Anthropic console, the workspace's limits: a monthly spend limit, in USD. Answer: set or not, and the sum; the sum goes into T69's «Сделано» | T69 | (a) set, at the sum the author names; the next step is В39; (b) not now: the key does not go in, platform AI stays closed, T69 waits | (a): without a limit a leaked key or a loop of calls spends without a ceiling, and the quota of `api` (R55 api) is only the second fence |
| В39 | The platform's key of Anthropic, as the first version of the secret `api-anthropic-key`, made empty by the merge of pull request 92. In Cloud Shell, signed in as an owner of `novatrail`, typed and never shown: `read -rsp "key: " KEY; echo; printf '%s' "$KEY" \| gcloud secrets versions add api-anthropic-key --project=novatrail --data-file=- && unset KEY`, then `gcloud secrets versions list api-anthropic-key --project=novatrail --format='value(name,state)'`. Answer: the version's number and `enabled`, never the key | T69 | (a) added: the version's number goes into `api_anthropic_key_version` of the second pull request; (b) not now: T69 waits | (a): the version must be there before the second merge, whose apply mounts it (architecture 3.8) |
| В40 | Whether the database `api` holds an account other than the author's (R149 spec; В23). Neon console → project «novatrail» → branch `production` → SQL Editor → database `api`: `SELECT auth_uid, adult_stated_at, deleting_at FROM accounts ORDER BY adult_stated_at;`, and compare each `auth_uid` with the author's «User UID» in Firebase console → Authentication → Users. Answer: how many rows and how many are not the author's — never a UID or an email. The second adult of the 2026-11-12 amendment to R25 may have one | T69 | (a) only the author's: the second pull request goes; (b) another account, the second adult's: the person deletes it in `app` themselves, and the second pull request goes once `deleting_at` is set; (c) another account, kept: the author asks the person not to sign in until row 6.24, and the second pull request goes — their work would reach Anthropic under the untruthful fact; (d) an account the author does not know: stop, and [BREACH.md](../BREACH.md), section 1 | (a) if so; else (b): R149 spec opens AI to whoever has an account, and the fact `minimal_retention` is declared for the author's work alone |
